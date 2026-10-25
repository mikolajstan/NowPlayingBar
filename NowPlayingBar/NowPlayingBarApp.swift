//
//  NowPlayingBarApp.swift
//  NowPlayingBar
//
//  Created by miki on 14/10/2026.
//

import SwiftUI

@main
struct NowPlayingBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu bar item and popover are AppKit (see StatusItemController);
        // the app still needs one scene
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let adapter = MediaRemoteAdapter()
    private let settings = AppSettings.shared
    private var statusItemController: StatusItemController?
    private var settingsWindow: NSWindow?

    /// Posted by a second launch, to the instance that's already running
    private static let showPopoverNotification = Notification.Name("NowPlayingBar.showPopover")
    private static let quitNotification = Notification.Name("NowPlayingBar.quit")

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard handOffToRunningInstance() == false else { return }

        // Start streaming at launch so the menu bar title shows without opening the popover
        adapter.start()

        statusItemController = StatusItemController(
            adapter: adapter,
            settings: settings,
            openSettings: { [weak self] panelFrame in self?.showSettings(nextTo: panelFrame) }
        )
    }

    // MARK: - Single Instance

    /// Only one copy should run (e.g. an exported app plus one in /Applications, or the same app opened twice).
    /// A release build that finds one already running opens that one's popover and quits itself;
    /// a debug build (run from Xcode) quits the running one instead and carries on.
    /// Returns true when this instance is quitting.
    private func handOffToRunningInstance() -> Bool {
        let center = DistributedNotificationCenter.default()
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != NSRunningApplication.current }

        if !others.isEmpty {
            #if DEBUG
            center.postNotificationName(Self.quitNotification, object: bundleID, deliverImmediately: true)
            #else
            center.postNotificationName(Self.showPopoverNotification, object: bundleID, deliverImmediately: true)
            NSApp.terminate(nil)
            return true
            #endif
        }

        center.addObserver(forName: Self.showPopoverNotification, object: bundleID, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.statusItemController?.showPanel()
            }
        }
        center.addObserver(forName: Self.quitNotification, object: bundleID, queue: .main) { _ in
            MainActor.assumeIsolated {
                NSApp.terminate(nil)
            }
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        adapter.stop()
    }

    // MARK: - Settings Window

    /// Opens the settings window to the left of the popover so both stay visible
    private func showSettings(nextTo panelFrame: NSRect) {
        if settingsWindow == nil {
            let view = SettingsView()
                .environmentObject(adapter)
                .environmentObject(settings)

            let window = SettingsWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "NowPlayingBar Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        if let window = settingsWindow, !window.isVisible {
            // Size it from its content first: on first open the window doesn't have its final size yet,
            // which placed it under the popover
            if let content = window.contentViewController?.view {
                window.setContentSize(content.fittingSize)
            }
            let size = window.frame.size
            var origin = NSPoint(x: panelFrame.minX - 12 - size.width, y: panelFrame.maxY - size.height)
            if let visible = (NSScreen.screens.first { $0.frame.intersects(panelFrame) } ?? NSScreen.main)?.visibleFrame {
                origin.x = max(origin.x, visible.minX + 8)
                origin.y = max(origin.y, visible.minY + 8)
            }
            window.setFrameOrigin(origin)
        }

        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
        // In case macOS doesn't let the app activate
        settingsWindow?.orderFrontRegardless()
    }
}
