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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start streaming at launch so the menu bar title shows without opening the popover
        adapter.start()

        statusItemController = StatusItemController(
            adapter: adapter,
            settings: settings,
            openSettings: { [weak self] in self?.showSettings() }
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        adapter.stop()
    }

    // MARK: - Settings Window

    private func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView()
                .environmentObject(adapter)
                .environmentObject(settings)

            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "NowPlayingBar Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }

        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
