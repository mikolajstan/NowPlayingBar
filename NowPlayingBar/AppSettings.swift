//
//  AppSettings.swift
//  NowPlayingBar
//

import SwiftUI
import Combine

/// User-adjustable look of the menu bar item and the popover, saved in UserDefaults
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    private let defaults: UserDefaults

    // MARK: - Menu Bar Item

    /// Width of the menu bar item in points (the maximum when `menuBarShrinkToFit` is on)
    @Published var menuBarWidth: Double { didSet { save(menuBarWidth, .menuBarWidth) } }

    /// Let short titles use less than `menuBarWidth` instead of a fixed width
    @Published var menuBarShrinkToFit: Bool { didSet { save(menuBarShrinkToFit, .menuBarShrinkToFit) } }

    /// Show the tiny artwork before the title
    @Published var menuBarShowArtwork: Bool { didSet { save(menuBarShowArtwork, .menuBarShowArtwork) } }

    /// Show "Title - Artist" instead of just the title
    @Published var menuBarShowArtist: Bool { didSet { save(menuBarShowArtist, .menuBarShowArtist) } }

    /// Marquee speed in points per second
    @Published var menuBarScrollSpeed: Double { didSet { save(menuBarScrollSpeed, .menuBarScrollSpeed) } }

    /// Space between the background's edges and the artwork/text
    @Published var menuBarHorizontalPadding: Double { didSet { save(menuBarHorizontalPadding, .menuBarHorizontalPadding) } }
    
    /// Gap above and below the background (smaller makes it taller)
    @Published var menuBarBackgroundInset: Double { didSet { save(menuBarBackgroundInset, .menuBarBackgroundInset) } }
    
    /// Draw a rounded background behind the menu bar item
    @Published var menuBarBackgroundEnabled: Bool { didSet { save(menuBarBackgroundEnabled, .menuBarBackgroundEnabled) } }
    @Published var menuBarBackgroundColor: Color { didSet { save(menuBarBackgroundColor, .menuBarBackgroundColor) } }
    @Published var menuBarBackgroundOpacity: Double { didSet { save(menuBarBackgroundOpacity, .menuBarBackgroundOpacity) } }

    /// Use `menuBarTextColor` instead of the menu bar's own text color
    @Published var menuBarTextColorEnabled: Bool { didSet { save(menuBarTextColorEnabled, .menuBarTextColorEnabled) } }
    @Published var menuBarTextColor: Color { didSet { save(menuBarTextColor, .menuBarTextColor) } }
    
    /// Opacity of the menu bar item's artwork and text while paused (1 = no dimming)
    @Published var menuBarPausedOpacity: Double { didSet { save(menuBarPausedOpacity, .menuBarPausedOpacity) } }

    /// Use `menuBarPausedColor` for the text while paused
    @Published var menuBarPausedTintEnabled: Bool { didSet { save(menuBarPausedTintEnabled, .menuBarPausedTintEnabled) } }
    @Published var menuBarPausedColor: Color { didSet { save(menuBarPausedColor, .menuBarPausedColor) } }

    // MARK: - Popover

    /// Keep the popover open when another app is clicked; it then closes from the menu bar item, Esc or ⌘W
    @Published var popoverStaysOpen: Bool { didSet { save(popoverStaysOpen, .popoverStaysOpen) } }
    
    /// Side of the square artwork in points
    @Published var popoverArtworkSize: Double { didSet { save(popoverArtworkSize, .popoverArtworkSize) } }

    /// Alignment of the title, artist and album
    @Published var popoverTextAlignment: PopoverTextAlignment { didSet { save(popoverTextAlignment.rawValue, .popoverTextAlignment) } }

    /// Vertical spacing between the popover sections
    @Published var popoverSpacing: Double { didSet { save(popoverSpacing, .popoverSpacing) } }

    @Published var popoverShowAlbum: Bool { didSet { save(popoverShowAlbum, .popoverShowAlbum) } }

    /// Blurred artwork behind the whole popover
    @Published var popoverBlurredBackground: Bool { didSet { save(popoverBlurredBackground, .popoverBlurredBackground) } }
    @Published var popoverBlurRadius: Double { didSet { save(popoverBlurRadius, .popoverBlurRadius) } }

    /// Opacity of the blurred artwork (lower lets more of the material through)
    @Published var popoverBackgroundOpacity: Double { didSet { save(popoverBackgroundOpacity, .popoverBackgroundOpacity) } }

    /// Circle behind the playback buttons, and its color on hover
    @Published var buttonBackgroundColor: Color { didSet { save(buttonBackgroundColor, .buttonBackgroundColor) } }
    @Published var buttonHoverColor: Color { didSet { save(buttonHoverColor, .buttonHoverColor) } }

    /// What the source label at the top of the popover shows
    @Published var sourceLabelStyle: SourceLabelStyle { didSet { save(sourceLabelStyle.rawValue, .sourceLabelStyle) } }
    
    /// Fill of the seek bar
    @Published var seekBarColor: Color { didSet { save(seekBarColor, .seekBarColor) } }

    // MARK: - Sources
    
    /// Only show sources whose domain or app is allowed
    @Published var sourceFilterEnabled: Bool { didSet { save(sourceFilterEnabled, .sourceFilterEnabled) } }
    
    /// Domains to show (subdomains included), checked against web apps and browser tabs
    @Published var allowedDomains: [String] { didSet { save(allowedDomains, .allowedDomains) } }
    
    /// Bundle IDs of apps to always show (e.g. Spotify)
    @Published var allowedApps: [String] { didSet { save(allowedApps, .allowedApps) } }
    
    /// For a plain browser, ask it over AppleScript which tab is playing
    @Published var browserTabLookupEnabled: Bool { didSet { save(browserTabLookupEnabled, .browserTabLookupEnabled) } }
    
    /// Width of the popover; never narrower than the artwork plus padding
    var popoverWidth: Double {
        max(popoverArtworkSize + 48, 280)
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        menuBarWidth = defaults.object(forKey: Key.menuBarWidth.rawValue) as? Double ?? 220
        menuBarShrinkToFit = defaults.object(forKey: Key.menuBarShrinkToFit.rawValue) as? Bool ?? false
        menuBarShowArtwork = defaults.object(forKey: Key.menuBarShowArtwork.rawValue) as? Bool ?? true
        menuBarShowArtist = defaults.object(forKey: Key.menuBarShowArtist.rawValue) as? Bool ?? true
        menuBarScrollSpeed = defaults.object(forKey: Key.menuBarScrollSpeed.rawValue) as? Double ?? 30
        menuBarHorizontalPadding = defaults.object(forKey: Key.menuBarHorizontalPadding.rawValue) as? Double ?? 6
        menuBarBackgroundInset = defaults.object(forKey: Key.menuBarBackgroundInset.rawValue) as? Double ?? 2
        menuBarBackgroundEnabled = defaults.object(forKey: Key.menuBarBackgroundEnabled.rawValue) as? Bool ?? true
        menuBarBackgroundColor = Self.color(defaults, .menuBarBackgroundColor) ?? .gray
        menuBarBackgroundOpacity = defaults.object(forKey: Key.menuBarBackgroundOpacity.rawValue) as? Double ?? 0.2
        menuBarTextColorEnabled = defaults.object(forKey: Key.menuBarTextColorEnabled.rawValue) as? Bool ?? false
        menuBarTextColor = Self.color(defaults, .menuBarTextColor) ?? .primary
        menuBarPausedOpacity = defaults.object(forKey: Key.menuBarPausedOpacity.rawValue) as? Double ?? 0.5
        menuBarPausedTintEnabled = defaults.object(forKey: Key.menuBarPausedTintEnabled.rawValue) as? Bool ?? false
        menuBarPausedColor = Self.color(defaults, .menuBarPausedColor) ?? .secondary

        popoverStaysOpen = defaults.object(forKey: Key.popoverStaysOpen.rawValue) as? Bool ?? false
        popoverArtworkSize = defaults.object(forKey: Key.popoverArtworkSize.rawValue) as? Double ?? 220
        popoverTextAlignment = (defaults.string(forKey: Key.popoverTextAlignment.rawValue))
            .flatMap(PopoverTextAlignment.init(rawValue:)) ?? .center
        popoverSpacing = defaults.object(forKey: Key.popoverSpacing.rawValue) as? Double ?? 14
        popoverShowAlbum = defaults.object(forKey: Key.popoverShowAlbum.rawValue) as? Bool ?? true
        popoverBlurredBackground = defaults.object(forKey: Key.popoverBlurredBackground.rawValue) as? Bool ?? true
        popoverBlurRadius = defaults.object(forKey: Key.popoverBlurRadius.rawValue) as? Double ?? 40
        popoverBackgroundOpacity = defaults.object(forKey: Key.popoverBackgroundOpacity.rawValue) as? Double ?? 0.6
        buttonBackgroundColor = Self.color(defaults, .buttonBackgroundColor) ?? Color.primary.opacity(0.08)
        buttonHoverColor = Self.color(defaults, .buttonHoverColor) ?? Color.primary.opacity(0.18)
        seekBarColor = Self.color(defaults, .seekBarColor) ?? .accentColor
        sourceLabelStyle = defaults.string(forKey: Key.sourceLabelStyle.rawValue)
            .flatMap(SourceLabelStyle.init(rawValue:)) ?? .iconAndName
        
        sourceFilterEnabled = defaults.object(forKey: Key.sourceFilterEnabled.rawValue) as? Bool ?? true
        allowedDomains = defaults.stringArray(forKey: Key.allowedDomains.rawValue) ?? ["music.youtube.com"]
        allowedApps = defaults.stringArray(forKey: Key.allowedApps.rawValue) ?? []
        browserTabLookupEnabled = defaults.object(forKey: Key.browserTabLookupEnabled.rawValue) as? Bool ?? true
    }

    /// Restore the default look; the source settings are kept
    func resetToDefaults() {
        for key in Key.lookKeys {
            defaults.removeObject(forKey: key.rawValue)
        }
        let fresh = AppSettings(defaults: defaults)

        menuBarWidth = fresh.menuBarWidth
        menuBarShrinkToFit = fresh.menuBarShrinkToFit
        menuBarShowArtwork = fresh.menuBarShowArtwork
        menuBarShowArtist = fresh.menuBarShowArtist
        menuBarScrollSpeed = fresh.menuBarScrollSpeed
        menuBarHorizontalPadding = fresh.menuBarHorizontalPadding
        menuBarBackgroundInset = fresh.menuBarBackgroundInset
        menuBarBackgroundEnabled = fresh.menuBarBackgroundEnabled
        menuBarBackgroundColor = fresh.menuBarBackgroundColor
        menuBarBackgroundOpacity = fresh.menuBarBackgroundOpacity
        menuBarTextColorEnabled = fresh.menuBarTextColorEnabled
        menuBarTextColor = fresh.menuBarTextColor
        menuBarPausedOpacity = fresh.menuBarPausedOpacity
        menuBarPausedTintEnabled = fresh.menuBarPausedTintEnabled
        menuBarPausedColor = fresh.menuBarPausedColor
        popoverStaysOpen = fresh.popoverStaysOpen
        popoverArtworkSize = fresh.popoverArtworkSize
        popoverTextAlignment = fresh.popoverTextAlignment
        popoverSpacing = fresh.popoverSpacing
        popoverShowAlbum = fresh.popoverShowAlbum
        popoverBlurredBackground = fresh.popoverBlurredBackground
        popoverBlurRadius = fresh.popoverBlurRadius
        popoverBackgroundOpacity = fresh.popoverBackgroundOpacity
        buttonBackgroundColor = fresh.buttonBackgroundColor
        buttonHoverColor = fresh.buttonHoverColor
        seekBarColor = fresh.seekBarColor
        sourceLabelStyle = fresh.sourceLabelStyle

        // The assignments above saved the defaults again; clear them so future default changes apply
        for key in Key.lookKeys {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    // MARK: - Persistence

    private enum Key: String, CaseIterable {
        case menuBarWidth, menuBarShrinkToFit, menuBarShowArtwork, menuBarShowArtist, menuBarScrollSpeed
        case menuBarBackgroundEnabled, menuBarBackgroundColor, menuBarBackgroundOpacity
        case menuBarPausedOpacity, menuBarPausedTintEnabled, menuBarPausedColor
        case popoverArtworkSize, popoverTextAlignment, popoverSpacing, popoverShowAlbum
        case popoverBlurredBackground, popoverBlurRadius, popoverBackgroundOpacity
        case buttonBackgroundColor, buttonHoverColor, seekBarColor
        case menuBarTextColorEnabled, menuBarTextColor, sourceLabelStyle
        case menuBarHorizontalPadding, menuBarBackgroundInset, popoverStaysOpen
        case sourceFilterEnabled, allowedDomains, allowedApps, browserTabLookupEnabled
        
        /// Everything except the source settings
        static var lookKeys: [Key] {
            allCases.filter { ![.sourceFilterEnabled, .allowedDomains, .allowedApps, .browserTabLookupEnabled].contains($0) }
        }
    }

    private func save(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    /// Colors are stored as sRGB components so they survive relaunches
    private func save(_ color: Color, _ key: Key) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
        defaults.set([rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent], forKey: key.rawValue)
    }

    private static func color(_ defaults: UserDefaults, _ key: Key) -> Color? {
        guard let c = defaults.array(forKey: key.rawValue) as? [Double], c.count == 4 else { return nil }
        return Color(.sRGB, red: c[0], green: c[1], blue: c[2], opacity: c[3])
    }
}

enum PopoverTextAlignment: String, CaseIterable, Identifiable {
    case leading, center

    var id: String { rawValue }

    var horizontal: HorizontalAlignment {
        self == .leading ? .leading : .center
    }

    var text: TextAlignment {
        self == .leading ? .leading : .center
    }

    var frame: Alignment {
        self == .leading ? .leading : .center
    }
}

enum SourceLabelStyle: String, CaseIterable, Identifiable {
    case iconAndName, iconOnly, nameOnly
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .iconAndName: "Icon and name"
        case .iconOnly: "Icon only"
        case .nameOnly: "Name only"
        }
    }
    
    var showsIcon: Bool { self != .nameOnly }
    var showsName: Bool { self != .iconOnly }
}
