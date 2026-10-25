//
//  MenuBarLabel.swift
//  NowPlayingBar
//

import SwiftUI

/// The menu bar item: tiny artwork, a smoothly scrolling title, and an optional background
struct MenuBarLabel: View {
    @EnvironmentObject var adapter: MediaRemoteAdapter
    @EnvironmentObject var settings: AppSettings

    /// Reports the width the status item should have
    var onWidthChange: (CGFloat) -> Void

    /// Width of the full text on one line, measured off-screen
    @State private var textWidth: CGFloat = 0

    static let artworkSize: CGFloat = 16
    static let spacing: CGFloat = 5
    static let font = NSFont.menuBarFont(ofSize: 0)

    var body: some View {
        Group {
            if let info = adapter.nowPlaying {
                trackLabel(info)
            } else {
                Image(systemName: "music.note")
                    .frame(width: 24)
                    .onAppear { onWidthChange(24) }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Track

    private func trackLabel(_ info: NowPlayingInfo) -> some View {
        let isPaused = info.playing != true
        let showArtwork = settings.menuBarShowArtwork
        let width = itemWidth(showArtwork: showArtwork)

        return HStack(spacing: Self.spacing) {
            if showArtwork {
                artwork
            }

            MarqueeText(
                text: text(for: info),
                font: Self.font,
                color: textColor(isPaused: isPaused),
                speed: settings.menuBarScrollSpeed,
                textWidth: $textWidth
            )
        }
        // Only the content dims while paused, so the background keeps its own opacity
        .opacity(isPaused ? settings.menuBarPausedOpacity : 1)
        .padding(.horizontal, settings.menuBarHorizontalPadding)
        .frame(width: width, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background {
            if settings.menuBarBackgroundEnabled {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(settings.menuBarBackgroundColor.opacity(settings.menuBarBackgroundOpacity))
                    .padding(.vertical, settings.menuBarBackgroundInset)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isPaused)
        .onChange(of: width, initial: true) { _, newValue in
            onWidthChange(newValue)
        }
    }

    /// Paused color, custom color, or nil for the menu bar's own text color
    private func textColor(isPaused: Bool) -> NSColor? {
        if isPaused && settings.menuBarPausedTintEnabled {
            return NSColor(settings.menuBarPausedColor)
        }
        if settings.menuBarTextColorEnabled {
            return NSColor(settings.menuBarTextColor)
        }
        return nil
    }

    private var artwork: some View {
        Group {
            if let artwork = adapter.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.primary.opacity(0.15))
            }
        }
        .frame(width: Self.artworkSize, height: Self.artworkSize)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    // MARK: - Layout

    private func text(for info: NowPlayingInfo) -> String {
        let title = info.displayTitle ?? "Unknown"
        guard settings.menuBarShowArtist, let artist = info.displayArtist, !artist.isEmpty else {
            return title
        }
        return "\(title) - \(artist)"
    }

    /// Fixed at the configured width, or shrunk to the text when that's enabled
    private func itemWidth(showArtwork: Bool) -> CGFloat {
        let chrome = settings.menuBarHorizontalPadding * 2 + (showArtwork ? Self.artworkSize + Self.spacing : 0)
        let maxWidth = max(CGFloat(settings.menuBarWidth), chrome + 20)
        guard settings.menuBarShrinkToFit, textWidth > 0 else { return maxWidth }
        return min(chrome + ceil(textWidth), maxWidth)
    }
}

// MARK: - Marquee

/// Single-line text that scrolls when it doesn't fit, pausing at the start of each loop.
///
/// The text is drawn by `CATextLayer`s and moved by a Core Animation animation, so it runs in
/// the render server at sub-pixel precision and stays smooth at any speed. (Text views would only
/// draw the part that's visible at the start, leaving the rest of a long title blank.)
struct MarqueeText: NSViewRepresentable {
    let text: String
    let font: NSFont
    /// nil uses the menu bar's text color
    let color: NSColor?
    /// Points per second
    let speed: Double
    /// Width of the full text on one line
    @Binding var textWidth: CGFloat

    func makeNSView(context: Context) -> MarqueeView {
        MarqueeView()
    }

    func updateNSView(_ view: MarqueeView, context: Context) {
        view.configure(text: text, font: font, color: color, speed: speed)

        let width = view.textWidth
        if width != textWidth {
            DispatchQueue.main.async { textWidth = width }
        }
    }
}

final class MarqueeView: NSView {
    /// Holds the text and its repeat; this is what moves
    private let strip = CALayer()
    private let first = CATextLayer()
    private let second = CATextLayer()
    private let fadeMask = CAGradientLayer()

    private(set) var textWidth: CGFloat = 0
    private var text = ""
    private var font = NSFont.menuBarFont(ofSize: 0)
    private var color: NSColor?
    private var speed: Double = 0
    /// What the running animation was made for, so it only restarts when something changed
    private var animationKey = ""

    /// Gap between the end of the text and its repeat
    private let gap: CGFloat = 32
    /// Rest at the start of each loop, in seconds
    private let pause: Double = 2
    /// Width of the faded edges
    private let fade: CGFloat = 8

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.addSublayer(strip)
        strip.addSublayer(first)
        strip.addSublayer(second)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Clicks go to the status bar button
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func configure(text: String, font: NSFont, color: NSColor?, speed: Double) {
        self.text = text
        self.font = font
        self.color = color
        self.speed = speed
        textWidth = ceil(NSAttributedString(string: text, attributes: [.font: font]).size().width)
        needsLayout = true
    }

    /// Menu bar light/dark changes resolve the text color again
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }

    override func layout() {
        super.layout()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        // Resolve the (possibly dynamic) color for the menu bar's current appearance
        var cgColor = NSColor.labelColor.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            cgColor = (color ?? .labelColor).cgColor
        }
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: cgColor,
        ])

        let height = ceil(font.ascender - font.descender + font.leading)
        let y = ((bounds.height - height) / 2).rounded()
        let scale = window?.backingScaleFactor ?? 2
        for (index, textLayer) in [first, second].enumerated() {
            textLayer.string = attributed
            textLayer.contentsScale = scale
            textLayer.frame = CGRect(x: CGFloat(index) * (textWidth + gap), y: y, width: textWidth, height: height)
        }
        strip.frame = CGRect(x: 0, y: 0, width: textWidth * 2 + gap, height: bounds.height)

        let overflows = textWidth > bounds.width + 0.5
        let scrolls = overflows && speed > 0
        second.isHidden = !scrolls
        updateMask(overflows: overflows, scrolls: scrolls)
        updateAnimation(scrolls: scrolls)
    }

    /// Fade both edges while scrolling, only the trailing edge when the text is cut off
    private func updateMask(overflows: Bool, scrolls: Bool) {
        guard overflows, bounds.width > fade * 2 else {
            layer?.mask = nil
            return
        }
        let edge = NSNumber(value: Double(fade / bounds.width))
        let end = NSNumber(value: 1 - Double(fade / bounds.width))
        fadeMask.frame = bounds
        fadeMask.startPoint = CGPoint(x: 0, y: 0.5)
        fadeMask.endPoint = CGPoint(x: 1, y: 0.5)
        if scrolls {
            fadeMask.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
            fadeMask.locations = [0, edge, end, 1]
        } else {
            fadeMask.colors = [NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
            fadeMask.locations = [0, end, 1]
        }
        layer?.mask = fadeMask
    }

    private func updateAnimation(scrolls: Bool) {
        let key = scrolls ? "\(text)|\(textWidth)|\(speed)" : ""
        guard key != animationKey || (scrolls && strip.animation(forKey: "marquee") == nil) else { return }
        animationKey = key

        strip.removeAnimation(forKey: "marquee")
        guard scrolls else { return }

        let distance = textWidth + gap
        let travel = Double(distance) / speed

        // Rest for `pause`, then move one text width + gap, at which point the repeat sits
        // exactly where the text started, so the loop is seamless
        let move = CABasicAnimation(keyPath: "transform.translation.x")
        move.fromValue = 0
        move.toValue = -distance
        move.beginTime = pause
        move.duration = travel

        let loop = CAAnimationGroup()
        loop.animations = [move]
        loop.duration = pause + travel
        loop.repeatCount = .infinity
        loop.isRemovedOnCompletion = false
        strip.add(loop, forKey: "marquee")
    }
}
