//
//  SourceFilter.swift
//  NowPlayingBar
//

import AppKit

/// Decides whether the now playing source should be shown, by domain or by app.
///
/// The adapter only reports bundle IDs, so the domain comes from:
/// 1. a web app's start URL in its Info.plist (e.g. music.youtube.com), or
/// 2. as a fallback for a plain browser, the URL of the tab whose title contains the track title,
///    asked for over AppleScript (needs the Automation permission).
final class SourceFilter {

    enum Decision {
        case allowed
        case blocked
        /// A browser tab lookup is running; call `decide` again when `onLookupFinished` fires
        case pending
    }

    /// Called on the main actor after a browser tab lookup finishes
    var onLookupFinished: (() -> Void)?

    private let settings: AppSettings

    /// Domain of each web app, by bundle ID (nil when it isn't a web app)
    private var webAppDomains: [String: String?] = [:]

    /// Browser tab lookups, by "bundleID|title" ("" when no matching tab was found)
    private var tabDomains: [String: String] = [:]
    private var runningLookups: Set<String> = []

    /// Browsers whose tabs can be read over AppleScript; Safari names the tab title `name`, the others `title`
    static let browsers: [String: String] = [
        "com.apple.Safari": "name",
        "com.apple.SafariTechnologyPreview": "name",
        "com.google.Chrome": "title",
        "com.brave.Browser": "title",
        "com.microsoft.edgemac": "title",
        "com.vivaldi.Vivaldi": "title",
        "company.thebrowser.Browser": "title",
    ]

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Decision

    func decide(_ info: NowPlayingInfo) -> Decision {
        guard settings.sourceFilterEnabled else { return .allowed }
        guard let bundleID = info.sourceApp else { return .blocked }

        if settings.allowedApps.contains(bundleID) {
            return .allowed
        }

        if let domain = webAppDomain(bundleID) {
            return isAllowed(domain: domain) ? .allowed : .blocked
        }

        if settings.browserTabLookupEnabled, let titleKey = Self.browsers[bundleID], let title = info.displayTitle, !title.isEmpty {
            let key = "\(bundleID)|\(title)"
            if let cached = tabDomains[key] {
                return isAllowed(domain: cached) ? .allowed : .blocked
            }
            lookUpTab(key: key, bundleID: bundleID, titleKey: titleKey, title: title)
            return .pending
        }

        return .blocked
    }

    /// Domain the source plays from, if known, for showing in the popover
    func domain(for info: NowPlayingInfo) -> String? {
        guard let bundleID = info.sourceApp else { return nil }
        if let domain = webAppDomain(bundleID) { return domain }
        if let title = info.displayTitle, let cached = tabDomains["\(bundleID)|\(title)"], !cached.isEmpty { return cached }
        return nil
    }

    /// `music.youtube.com` allows itself and its subdomains, but not `www.youtube.com`
    func isAllowed(domain: String) -> Bool {
        let host = domain.lowercased()
        return settings.allowedDomains.contains { allowed in
            let allowed = allowed.lowercased().trimmingCharacters(in: .whitespaces)
            return !allowed.isEmpty && (host == allowed || host.hasSuffix("." + allowed))
        }
    }

    // MARK: - Web Apps

    /// Host of a Safari web app's start URL, read from `Manifest.start_url` in its Info.plist
    private func webAppDomain(_ bundleID: String) -> String? {
        if let cached = webAppDomains[bundleID] { return cached }

        var domain: String?
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let manifest = Bundle(url: url)?.object(forInfoDictionaryKey: "Manifest") {
            var startURL: String?
            if let dict = manifest as? [String: Any] {
                startURL = dict["start_url"] as? String
            } else if let json = (manifest as? String)?.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: json) as? [String: Any] {
                startURL = dict["start_url"] as? String
            }
            domain = startURL.flatMap { URL(string: $0)?.host() }
        }

        webAppDomains[bundleID] = domain
        return domain
    }

    // MARK: - Browser Tabs

    /// Ask the browser for the URL of the tab whose title contains the track title
    private func lookUpTab(key: String, bundleID: String, titleKey: String, title: String) {
        guard !runningLookups.contains(key) else { return }
        runningLookups.insert(key)

        let source = """
        tell application id "\(bundleID)"
            set tabURLs to URL of every tab of every window
            set tabTitles to \(titleKey) of every tab of every window
        end tell
        set AppleScript's text item delimiters to linefeed
        set out to {}
        repeat with w from 1 to count of tabURLs
            repeat with t from 1 to count of item w of tabURLs
                set end of out to (item t of item w of tabTitles) & tab & (item t of item w of tabURLs)
            end repeat
        end repeat
        return out as text
        """

        Task { [weak self] in
            let domain = await Task.detached {
                Self.runTabScript(source, bundleID: bundleID, title: title)
            }.value
            
            guard let self else { return }
            self.runningLookups.remove(key)
            // Failures (nil, e.g. permission denied) aren't cached, so granting permission later works
            if let domain {
                self.tabDomains[key] = domain
            }
            self.onLookupFinished?()
        }
    }
    
    /// Runs the tab listing script; returns the matching tab's host, "" when no tab matched,
    /// or nil when the script failed
    nonisolated private static func runTabScript(_ source: String, bundleID: String, title: String) -> String? {
        var error: NSDictionary?
        guard let output = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue, error == nil else {
            print("⚠️ Tab lookup in \(bundleID) failed: \(error ?? [:])")
            return nil
        }
        
        // Lines of "title<TAB>url"; the tab whose title contains the track title
        return output
            .split(separator: "\n")
            .map { $0.split(separator: "\t", maxSplits: 1).map(String.init) }
            .first { $0.count == 2 && $0[0].localizedCaseInsensitiveContains(title) }
            .flatMap { URL(string: $0[1])?.host() } ?? ""
    }
}
