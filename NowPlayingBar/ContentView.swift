//
//  ContentView.swift
//  NowPlayingBar
//
//  Created by miki on 14/10/2026.
//

import SwiftUI

struct ContentView: View {
    // Get the adapter from the environment
    @EnvironmentObject var adapter: MediaRemoteAdapter
    @EnvironmentObject var settings: AppSettings

    /// Opens the settings window
    var openSettings: () -> Void = {}

    // State for tracking current elapsed time (updates every second)
    @State private var currentElapsedTime: Double = 0
    @State private var timer: Timer?

    /// Whether the quick settings are expanded at the bottom
    @State private var showQuickSettings = false

    private var artworkSize: CGFloat { CGFloat(settings.popoverArtworkSize) }

    var body: some View {
        VStack(spacing: settings.popoverSpacing) {
            topBar

            if adapter.isRunning, let info = adapter.nowPlaying {
                nowPlaying(info)
            } else if let error = adapter.lastError {
                // Error state
                placeholder(
                    systemImage: "exclamationmark.triangle",
                    title: "Something went wrong",
                    message: error
                )
            } else if adapter.isRunning {
                // Nothing playing
                placeholder(
                    systemImage: "music.note",
                    title: "Nothing playing",
                    message: "Start something in YouTube Music and it will show up here."
                )
                .onAppear {
                    stopTimer()
                }
            } else {
                // Adapter not running yet
                placeholder(systemImage: nil, title: "Starting…", message: nil)
            }
            
            if showQuickSettings {
                QuickSettingsView(openSettings: openSettings)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(width: settings.popoverWidth)
        .background {
            PopoverBackground(
                artwork: settings.popoverBlurredBackground ? adapter.artwork : nil,
                blurRadius: settings.popoverBlurRadius,
                opacity: settings.popoverBackgroundOpacity
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
        .onAppear {
            // Start the adapter when the view appears
            adapter.start()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Sections

    /// Source app on the left, settings and quit on the right
    private var topBar: some View {
        HStack(spacing: 6) {
            if let info = adapter.nowPlaying {
                SourceLabel(info: info, domain: adapter.sourceDomain)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showQuickSettings.toggle()
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(IconButtonStyle(isOn: showQuickSettings))
            .help("Quick Settings")

            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(IconButtonStyle())
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings")

            // Quit button (also ⌘Q while the popover is open)
            Button(action: quit) {
                Image(systemName: "power")
            }
            .buttonStyle(IconButtonStyle())
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit NowPlayingBar")
        }
        .frame(height: 22)
    }

    private func nowPlaying(_ info: NowPlayingInfo) -> some View {
        // Changes when the track does, to crossfade artwork and text
        let trackKey = "\(info.title ?? "")|\(info.artist ?? "")"
        let alignment = settings.popoverTextAlignment

        return VStack(spacing: settings.popoverSpacing) {
            // ZStacks so the old and new track overlap while crossfading
            ZStack {
                artwork
                    .id(adapter.artwork.map { ObjectIdentifier($0) })
                    .transition(.opacity)
            }

            // Track info
            ZStack {
                VStack(alignment: alignment.horizontal, spacing: 3) {
                    Text(info.displayTitle ?? "Unknown Title")
                        .font(.headline)
                        .lineLimit(2, reservesSpace: true)
                        .frame(maxWidth: .infinity, alignment: alignment.frame)

                    Text(info.displayArtist ?? "Unknown Artist")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if settings.popoverShowAlbum {
                        // Kept (invisible) when empty so the popover doesn't change height
                        Text(info.displayAlbum.flatMap { $0.isEmpty ? nil : $0 } ?? " ")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .multilineTextAlignment(alignment.text)
                .frame(maxWidth: .infinity, alignment: alignment.frame)
                .id(trackKey)
                .transition(.opacity)
            }

            // Seek bar with elapsed time and duration at its ends
            VStack(spacing: 2) {
                ProgressBarView(
                    currentTime: $currentElapsedTime,
                    duration: info.duration ?? 0,
                    color: settings.seekBarColor,
                    onSeek: { newTime in
                        seekToPosition(newTime)
                    }
                )
                .frame(height: 20)

                HStack {
                    Text(formatTime(currentElapsedTime))
                    Spacer()
                    Text(info.formattedDuration)
                }
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }

            // Playback controls
            HStack(spacing: 18) {
                Button(action: {
                    changeTrack(.previousTrack)
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(CircleButtonStyle(diameter: 40))
                .help("Previous Track")

                Button(action: {
                    adapter.send(.togglePlayPause)
                }) {
                    Image(systemName: info.playing == true ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(CircleButtonStyle(diameter: 54))
                .help(info.playing == true ? "Pause" : "Play")

                Button(action: {
                    changeTrack(.nextTrack)
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(CircleButtonStyle(diameter: 40))
                .help("Next Track")
            }
        }
        .animation(.easeInOut(duration: 0.3), value: trackKey)
        .animation(.easeInOut(duration: 0.3), value: adapter.artwork.map { ObjectIdentifier($0) })
        .onChange(of: info.elapsedTime) { oldValue, newValue in
            // Update elapsed time when info changes
            currentElapsedTime = info.currentElapsedTime

            // Restart timer for live updates
            restartTimer(isPlaying: info.playing == true, playbackRate: info.playbackRate ?? 1.0)
        }
        .onChange(of: adapter.isChangingTrack) { oldValue, newValue in
            // Back to the reported position once the change lands (or times out)
            guard !newValue else { return }
            currentElapsedTime = info.currentElapsedTime
            restartTimer(isPlaying: info.playing == true, playbackRate: info.playbackRate ?? 1.0)
        }
        .onChange(of: info.playing) { oldValue, newValue in
            // Update timer when play state changes
            restartTimer(isPlaying: newValue == true, playbackRate: info.playbackRate ?? 1.0)
        }
        .onAppear {
            // Initialize elapsed time
            currentElapsedTime = info.currentElapsedTime
            restartTimer(isPlaying: info.playing == true, playbackRate: info.playbackRate ?? 1.0)
        }
    }

    /// Album artwork, or a placeholder of the same size
    private var artwork: some View {
        Group {
            if let artwork = adapter.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: artworkSize * 0.3, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: artworkSize, height: artworkSize)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .opacity(adapter.isChangingTrack ? 0.4 : 1)
        .overlay {
            if adapter.isChangingTrack {
                ProgressView()
            }
        }
        .animation(.easeOut(duration: 0.15), value: adapter.isChangingTrack)
    }

    /// Empty, loading and error states, the same size as the artwork so the popover keeps its size
    private func placeholder(systemImage: String?, title: String, message: String?) -> some View {
        VStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, options: .repeating, isActive: systemImage == "music.note")
            } else {
                ProgressView()
            }

            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: artworkSize)
        .padding(.bottom, 8)
    }

    // MARK: - Timer Management

    private func restartTimer(isPlaying: Bool, playbackRate: Double) {
        stopTimer()

        guard isPlaying else { return }

        // Create a timer that fires every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let info = adapter.nowPlaying {
                currentElapsedTime = info.currentElapsedTime
            } else {
                currentElapsedTime += playbackRate
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Media Commands

    /// Next/previous: reset the progress bar right away instead of waiting for the stream
    private func changeTrack(_ command: MediaRemoteAdapter.Command) {
        adapter.send(command)
        stopTimer()
        currentElapsedTime = 0
    }

    private func seekToPosition(_ position: Double) {
        adapter.seek(to: position)
        currentElapsedTime = position
    }

    // MARK: - App

    /// Stop the adapter's Perl process so it doesn't outlive the app, then quit
    private func quit() {
        adapter.stop()
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Helpers

func formatTime(_ seconds: Double) -> String {
    let totalSeconds = Int(max(seconds, 0))
    let minutes = totalSeconds / 60
    let remainingSeconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
}

// MARK: - Background

/// Popover material with the artwork blurred behind everything
struct PopoverBackground: View {
    let artwork: NSImage?
    let blurRadius: Double
    let opacity: Double

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover)

            if let artwork {
                GeometryReader { geometry in
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        // Scaled up so the blur doesn't fade out at the edges
                        .scaleEffect(1.4)
                        .blur(radius: blurRadius)
                        .saturation(1.3)
                        .opacity(opacity)
                        .clipped()
                }
                .transition(.opacity)
                .id(ObjectIdentifier(artwork))

                // Keeps text readable over bright artwork
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.4)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: artwork.map { ObjectIdentifier($0) })
    }
}

/// `NSVisualEffectView` for behind-window blur
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

// MARK: - Source Label

/// Icon and name of the app that's playing
struct SourceLabel: View {
    let info: NowPlayingInfo
    /// Domain it plays from, if known (shown on hover)
    var domain: String?

    var body: some View {
        let app = SourceApp.lookup(info.sourceApp)

        HStack(spacing: 5) {
            if let icon = app?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            Text(app?.name ?? info.sourceApp ?? "Unknown app")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .help(domain ?? info.sourceApp ?? "")
    }
}

/// Name and icon for a bundle ID, cached because the lookups hit the disk
struct SourceApp {
    let name: String
    let icon: NSImage

    private static var cache: [String: SourceApp] = [:]

    static func lookup(_ bundleIdentifier: String?) -> SourceApp? {
        guard let bundleIdentifier else { return nil }
        if let cached = cache[bundleIdentifier] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }

        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        let app = SourceApp(name: name, icon: NSWorkspace.shared.icon(forFile: url.path))
        cache[bundleIdentifier] = app
        return app
    }
}

// MARK: - Button Styles

/// Playback button with a background circle that highlights and grows on hover and shrinks when pressed
struct CircleButtonStyle: ButtonStyle {
    let diameter: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        CircleButton(configuration: configuration, diameter: diameter)
    }

    private struct CircleButton: View {
        let configuration: Configuration
        let diameter: CGFloat

        @EnvironmentObject var settings: AppSettings
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(.primary)
                .frame(width: diameter, height: diameter)
                .background {
                    Circle()
                        .fill(isHovering ? settings.buttonHoverColor : settings.buttonBackgroundColor)
                }
                .contentShape(Circle())
                .scaleEffect(configuration.isPressed ? 0.88 : (isHovering ? 1.08 : 1))
                .opacity(configuration.isPressed ? 0.75 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovering)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
                .onHover { isHovering = $0 }
                .pointerStyle(.link)
        }
    }
}

/// Small borderless icon button for the top bar
struct IconButtonStyle: ButtonStyle {
    /// Shows the button as selected (e.g. while the quick settings are open)
    var isOn = false

    func makeBody(configuration: Configuration) -> some View {
        IconButton(configuration: configuration, isOn: isOn)
    }

    private struct IconButton: View {
        let configuration: Configuration
        let isOn: Bool
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovering || isOn ? .primary : .secondary)
                .frame(width: 22, height: 22)
                .background {
                    Circle()
                        .fill(Color.primary.opacity(isHovering ? 0.12 : (isOn ? 0.08 : 0)))
                }
                .contentShape(Circle())
                .scaleEffect(configuration.isPressed ? 0.85 : 1)
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
                .onHover { isHovering = $0 }
                .pointerStyle(.link)
        }
    }
}

// MARK: - Progress Bar View

/// Seek bar: the whole 20 pt row is clickable; hovering thickens the track, shows a knob and the time under the cursor
struct ProgressBarView: View {
    @Binding var currentTime: Double
    let duration: Double
    let color: Color
    let onSeek: (Double) -> Void

    @State private var isHovering = false
    @State private var hoverX: CGFloat?
    @State private var dragPosition: Double?

    private var isActive: Bool { isHovering || dragPosition != nil }

    var progress: Double {
        guard duration > 0 else { return 0 }
        let time = dragPosition ?? currentTime
        return min(max(time / duration, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let trackHeight: CGFloat = isActive ? 8 : 5
            let knobSize: CGFloat = 12

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.primary.opacity(0.15))
                    .frame(height: trackHeight)

                // Progress fill
                Capsule()
                    .fill(color)
                    .frame(width: max(width * progress, trackHeight), height: trackHeight)

                // Knob at the current (or dragged) position
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: min(max(width * progress - knobSize / 2, 0), width - knobSize))
                    .opacity(isActive ? 1 : 0)
                    .scaleEffect(isActive ? 1 : 0.5)
            }
            .frame(width: width, height: geometry.size.height)
            .overlay(alignment: .topLeading) {
                // Time at the cursor (or the dragged position)
                if let x = dragPosition.map({ CGFloat($0 / max(duration, 1)) * width }) ?? hoverX, duration > 0 {
                    Text(formatTime(Double(min(max(x / width, 0), 1)) * duration))
                        .font(.caption2)
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.regularMaterial, in: Capsule())
                        .fixedSize()
                        .alignmentGuide(.leading) { $0.width / 2 - min(max(x, 18), width - 18) }
                        .offset(y: -20)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: isActive)
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    isHovering = true
                    hoverX = location.x
                case .ended:
                    isHovering = false
                    hoverX = nil
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        dragPosition = position(at: value.location.x, width: width)
                    }
                    .onEnded { value in
                        onSeek(position(at: value.location.x, width: width))
                        dragPosition = nil
                    }
            )
            .pointerStyle(.link)
        }
    }

    private func position(at x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return Double(min(max(x / width, 0), 1)) * duration
    }
}

#Preview {
    ContentView()
        .environmentObject(MediaRemoteAdapter())
        .environmentObject(AppSettings.shared)
}
