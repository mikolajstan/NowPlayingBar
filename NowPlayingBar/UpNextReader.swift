//
//  UpNextReader.swift
//  NowPlayingBar
//

import AppKit
import ApplicationServices
import Combine

/// One song in the YouTube Music queue
nonisolated struct QueueItem: Identifiable, Equatable, Sendable {
    /// Position in the queue
    let id: Int
    let title: String
    let artist: String
    let duration: String?
}

/// Reads the "Up next" queue from the YouTube Music web app.
///
/// MediaRemote doesn't carry the queue for web players, so this reads the page through
/// the Accessibility API instead. It needs the Accessibility permission, and YouTube Music only
/// puts the queue on the page once its player page has been opened.
@MainActor
final class UpNextReader: ObservableObject {

    enum State: Equatable {
        /// Not a Safari web app (e.g. a browser tab or a native app)
        case unsupported
        /// NowPlayingBar isn't allowed to use Accessibility yet
        case needsPermission
        /// No queue on the page: the player page hasn't been opened
        case playerPageClosed
        case ready
    }

    @Published private(set) var state: State = .unsupported

    /// Songs after the one that's playing
    @Published private(set) var upcoming: [QueueItem] = []

    private var info: NowPlayingInfo?
    private var timer: Timer?
    private var isReading = false

    /// How often the queue is read again while a web app plays, to catch songs added to it
    private static let refreshInterval: TimeInterval = 5

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    /// Read the queue for a new track (or none)
    func update(for info: NowPlayingInfo?) {
        let trackChanged = info?.title != self.info?.title || info?.sourceApp != self.info?.sourceApp
        self.info = info
        guard trackChanged else { return }

        refresh()
        // The page updates its queue a moment after the track changes
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.refresh()
        }
    }

    /// Read the queue from the web app that's playing
    func refresh() {
        guard let info, let bundleID = info.sourceApp, bundleID.contains("Safari.WebApp"),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            setState(.unsupported, upcoming: [])
            return
        }
        guard AXIsProcessTrusted() else {
            setState(.needsPermission, upcoming: [])
            return
        }
        guard !isReading else { return }
        isReading = true

        let pid = app.processIdentifier
        let title = info.title ?? ""
        Task { [weak self] in
            let queue = await Task.detached {
                Self.readQueue(pid: pid)
            }.value

            guard let self else { return }
            self.isReading = false
            guard !queue.isEmpty else {
                self.setState(.playerPageClosed, upcoming: [])
                return
            }
            self.setState(.ready, upcoming: Self.songsAfter(title: title, in: queue))
        }
    }

    /// Show the system prompt that sends the user to Privacy & Security > Accessibility
    func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func setState(_ state: State, upcoming: [QueueItem]) {
        if self.state != state { self.state = state }
        if self.upcoming != upcoming { self.upcoming = upcoming }
    }

    /// The songs after the playing one, found by its title (the page has no language-independent marker)
    private static func songsAfter(title: String, in queue: [QueueItem]) -> [QueueItem] {
        let title = title.trimmingCharacters(in: .whitespaces)
        guard let index = queue.firstIndex(where: {
            $0.title.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(title) == .orderedSame
        }) else {
            return []
        }
        return Array(queue[(index + 1)...])
    }

    // MARK: - Accessibility

    /// Read every queue row from the web app's player page; empty when there's no queue on the page.
    ///
    /// The rows aren't wrapped in one element each. Every part is a direct child of `#player-page`, in order:
    /// a `left-items` group (starts a row), the title text, an optional explicit badge, one or more
    /// artist texts, a `menu` group and a `duration` group (ends a row).
    nonisolated private static func readQueue(pid: pid_t) -> [QueueItem] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1)

        let windows = (attribute(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
        for window in windows {
            guard let webArea = webArea(in: window),
                  let playerPage = children(of: webArea).first(where: {
                      attribute($0, "AXDOMIdentifier") as? String == "player-page"
                  }) else { continue }

            let rows = queueRows(in: playerPage)
            if !rows.isEmpty { return rows }
        }
        return []
    }

    nonisolated private static func queueRows(in playerPage: AXUIElement) -> [QueueItem] {
        var rows: [QueueItem] = []
        var texts: [String]?
        var reachedMenu = false

        for element in children(of: playerPage) {
            let classes = domClasses(element)
            let isQueueItem = classes.contains("ytmusic-player-queue-item")

            if isQueueItem && classes.contains("left-items") {
                texts = []
                reachedMenu = false
            } else if isQueueItem && classes.contains("menu") {
                reachedMenu = true
            } else if isQueueItem && classes.contains("duration"), let rowTexts = texts, let title = rowTexts.first {
                let duration = children(of: element).compactMap { attribute($0, kAXValueAttribute) as? String }.first
                let artist = rowTexts.dropFirst().joined().trimmingCharacters(in: .whitespaces)
                rows.append(QueueItem(id: rows.count, title: title, artist: artist, duration: duration))
                texts = nil
            } else if texts != nil, !reachedMenu,
                      attribute(element, kAXRoleAttribute) as? String == kAXStaticTextRole,
                      let value = attribute(element, kAXValueAttribute) as? String {
                // The first text is the title; the rest (split up with several artists) is the artist
                texts?.append(value)
            }
        }
        return rows
    }

    /// The page's web area, a few levels under the window
    nonisolated private static func webArea(in window: AXUIElement) -> AXUIElement? {
        var level = [window]
        for _ in 0..<10 {
            var next: [AXUIElement] = []
            for element in level {
                if attribute(element, kAXRoleAttribute) as? String == "AXWebArea" {
                    return element
                }
                next += children(of: element)
            }
            level = next
        }
        return nil
    }

    nonisolated private static func children(of element: AXUIElement) -> [AXUIElement] {
        (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }

    /// The element's CSS classes
    nonisolated private static func domClasses(_ element: AXUIElement) -> [String] {
        switch attribute(element, "AXDOMClassList") {
        case let list as [String]: list
        case let string as String: string.split(separator: " ").map(String.init)
        default: []
        }
    }

    nonisolated private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}
