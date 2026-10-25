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
    static let horizontalPadding: CGFloat = 6
    static let font = Font(NSFont.menuBarFont(ofSize: 0))

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
                speed: settings.menuBarScrollSpeed,
                isScrolling: !isPaused,
                textWidth: $textWidth
            )
            .foregroundStyle(isPaused && settings.menuBarPausedTintEnabled
                             ? AnyShapeStyle(settings.menuBarPausedColor)
                             : AnyShapeStyle(.primary))
        }
        .padding(.horizontal, Self.horizontalPadding)
        .frame(width: width, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background {
            if settings.menuBarBackgroundEnabled {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(settings.menuBarBackgroundColor.opacity(settings.menuBarBackgroundOpacity))
                    .padding(.vertical, 2)
            }
        }
        .opacity(isPaused ? settings.menuBarPausedOpacity : 1)
        .animation(.easeInOut(duration: 0.25), value: isPaused)
        .onChange(of: width, initial: true) { _, newValue in
            onWidthChange(newValue)
        }
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
        let chrome = Self.horizontalPadding * 2 + (showArtwork ? Self.artworkSize + Self.spacing : 0)
        let maxWidth = max(CGFloat(settings.menuBarWidth), chrome + 20)
        guard settings.menuBarShrinkToFit, textWidth > 0 else { return maxWidth }
        return min(chrome + ceil(textWidth), maxWidth)
    }
}

// MARK: - Marquee

/// Single-line text that scrolls pixel by pixel when it doesn't fit, pausing at the start of each loop
struct MarqueeText: View {
    let text: String
    let font: Font
    /// Points per second
    let speed: Double
    let isScrolling: Bool
    @Binding var textWidth: CGFloat

    /// Gap between the end of the text and its repeat
    private let gap: CGFloat = 32
    /// Rest at the start of each loop, in seconds
    private let pause: Double = 2
    /// Width of the faded edges while scrolling
    private let fade: CGFloat = 8

    /// When the current loop started, so pausing and title changes restart from the beginning
    @State private var start = Date()

    var body: some View {
        GeometryReader { geometry in
            let overflows = textWidth > geometry.size.width + 0.5

            Group {
                if overflows && isScrolling && speed > 0 {
                    TimelineView(.animation(minimumInterval: 1 / 60)) { context in
                        HStack(spacing: gap) {
                            label
                            label
                        }
                        .offset(x: -offset(at: context.date))
                    }
                    .mask(fadeMask)
                } else {
                    label
                        .frame(width: geometry.size.width, alignment: .leading)
                        .mask(overflows ? AnyView(trailingFadeMask) : AnyView(Color.black))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            .clipped()
        }
        .background(alignment: .leading) {
            // Measures the text without limiting it to the visible width
            label
                .hidden()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
        }
        .onChange(of: text) { start = Date() }
        .onChange(of: isScrolling) { start = Date() }
    }

    private var label: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
    }

    private func offset(at date: Date) -> CGFloat {
        let distance = textWidth + gap
        let cycle = pause + distance / speed
        let t = date.timeIntervalSince(start).truncatingRemainder(dividingBy: cycle)
        return max(0, t - pause) * speed
    }

    private var fadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: fade)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: fade)
        }
    }

    private var trailingFadeMask: some View {
        HStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: fade)
        }
    }
}
