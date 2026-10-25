//
//  StatusItemController.swift
//  NowPlayingBar
//

import AppKit
import SwiftUI

/// Owns the menu bar item and the popover panel.
///
/// `MenuBarExtra` only renders plain text and images in its label and positions its window itself,
/// so the item is an `NSStatusItem` hosting a SwiftUI view, and the popover is a panel pinned under
/// the item's right edge.
final class StatusItemController: NSObject {

    private let statusItem: NSStatusItem
    private let panel: PopoverPanel
    private let adapter: MediaRemoteAdapter
    private let settings: AppSettings

    /// Set when clicking outside closes the panel, so a click on the item itself doesn't reopen it
    private var lastAutoClose = Date.distantPast

    init(adapter: MediaRemoteAdapter, settings: AppSettings, openSettings: @escaping () -> Void) {
        self.adapter = adapter
        self.settings = settings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        panel = PopoverPanel()
        super.init()

        // Menu bar item
        if let button = statusItem.button {
            let label = MenuBarLabel { [weak self] width in
                // Deferred: resizing the item while SwiftUI is laying it out triggers layout recursion
                DispatchQueue.main.async {
                    guard let self, self.statusItem.length != width else { return }
                    self.statusItem.length = width
                }
            }
            .environmentObject(adapter)
            .environmentObject(settings)

            let hostingView = PassthroughHostingView(rootView: label)
            hostingView.frame = button.bounds
            hostingView.autoresizingMask = [.width, .height]
            button.addSubview(hostingView)

            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Popover
        let content = ContentView(
            openSettings: { [weak self] in
                self?.closePanel()
                openSettings()
            }
        )
        .environmentObject(adapter)
        .environmentObject(settings)

        panel.contentView = FirstMouseHostingView(rootView: content)
        panel.onAutoClose = { [weak self] in
            self?.lastAutoClose = Date()
            self?.statusItem.button?.highlight(false)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(panelDidResize),
            name: NSWindow.didResizeNotification, object: panel
        )
    }

    // MARK: - Panel

    @objc private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else if Date().timeIntervalSince(lastAutoClose) > 0.3 {
            showPanel()
        }
    }

    private func showPanel() {
        NSApp.activate()
        if let content = panel.contentView {
            panel.setContentSize(content.fittingSize)
        }
        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)
    }

    private func closePanel() {
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
    }

    /// Keep the top-right corner pinned when the content changes size
    @objc private func panelDidResize() {
        positionPanel()
        panel.invalidateShadow()
    }

    /// Top-right corner under the right edge of the item, kept on screen
    private func positionPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }

        let itemFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let size = panel.frame.size
        var origin = NSPoint(x: itemFrame.maxX - size.width, y: itemFrame.minY - 6 - size.height)

        if let screen = buttonWindow.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        }

        if panel.frame.origin != origin {
            panel.setFrameOrigin(origin)
        }
    }
}

// MARK: - Panel Window

/// Borderless floating panel that looks like a menu bar popover and closes when it loses focus
final class PopoverPanel: NSPanel {

    /// Called when the panel closes because the user clicked elsewhere
    var onAutoClose: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        guard isVisible else { return }
        orderOut(nil)
        onAutoClose?()
    }

    override func cancelOperation(_ sender: Any?) {
        // Escape closes the popover
        orderOut(nil)
        onAutoClose?()
    }
}

// MARK: - Hosting Views

/// Lets clicks fall through to the status bar button underneath
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Handles the first click even when the panel isn't key yet, so the seek bar and buttons
/// react on the first try
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
