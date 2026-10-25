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
    
    // State for tracking current elapsed time (updates every second)
    @State private var currentElapsedTime: Double = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 12) {
            if adapter.isRunning {
                if let info = adapter.nowPlaying {
                    // Show now playing info
                    VStack(spacing: 12) {
                        // Album artwork
                        if let artwork = adapter.artwork {
                            Image(nsImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 200, height: 200)
                                .cornerRadius(8)
                                .shadow(radius: 4)
                                .opacity(adapter.isChangingTrack ? 0.4 : 1)
                                .overlay {
                                    if adapter.isChangingTrack {
                                        ProgressView()
                                    }
                                }
                                .animation(.easeOut(duration: 0.15), value: adapter.isChangingTrack)
                        } else {
                            // Placeholder when no artwork
                            Image(systemName: "music.note")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                        
                        // Track info
                        VStack(spacing: 4) {
                            Text(info.title ?? "Unknown Title")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text(info.artist ?? "Unknown Artist")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(info.album ?? "Unknown Album")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Progress bar (clickable for seeking)
                        ProgressBarView(
                            currentTime: $currentElapsedTime,
                            duration: info.duration ?? 0,
                            onSeek: { newTime in
                                seekToPosition(newTime)
                            }
                        )
                        .frame(height: 20)
                        .padding(.horizontal)
                        
                        // Timestamp display
                        HStack {
                            Text(formatTime(currentElapsedTime))
                                .font(.caption)
                                .monospacedDigit()
                            
                            Text("/")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(info.formattedDuration)
                                .font(.caption)
                                .monospacedDigit()
                        }
                        
                        // Playback controls
                        HStack(spacing: 20) {
                            // Previous button
                            Button(action: {
                                changeTrack(.previousTrack)
                            }) {
                                Image(systemName: "backward.fill")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .help("Previous Track")
                            
                            // Play/Pause button
                            Button(action: {
                                adapter.send(.togglePlayPause)
                            }) {
                                Image(systemName: info.playing == true ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .help(info.playing == true ? "Pause" : "Play")
                            
                            // Next button
                            Button(action: {
                                changeTrack(.nextTrack)
                            }) {
                                Image(systemName: "forward.fill")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .help("Next Track")
                        }
                        .padding(.top, 4)
                    }
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
                } else {
                    // Nothing playing
                    VStack {
                        Image(systemName: "music.note.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("Nothing playing")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        stopTimer()
                    }
                }
            } else if adapter.lastError == nil {
                // Adapter not running yet
                VStack {
                    ProgressView()
                    Text("Starting adapter...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Error display
            if let error = adapter.lastError {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(minWidth: 250)
        .onAppear {
            // Start the adapter when the view appears
            adapter.start()
        }
        .onDisappear {
            // Stop the timer and optionally the adapter
            stopTimer()
            // adapter.stop()
        }
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
    
    // MARK: - Helper Methods
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Button Style

/// Plain button that dims and shrinks slightly while pressed, so clicks register visibly
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Progress Bar View

struct ProgressBarView: View {
    @Binding var currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    @State private var dragPosition: Double?
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        let time = dragPosition ?? currentTime
        return min(max(time / duration, 0), 1)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 6)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: 6)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    if isDragging {
                        updateDragPosition(location.x, width: geometry.size.width)
                    }
                case .ended:
                    break
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        updateDragPosition(value.location.x, width: geometry.size.width)
                    }
                    .onEnded { value in
                        isDragging = false
                        if let position = dragPosition {
                            onSeek(position)
                        }
                        dragPosition = nil
                    }
            )
        }
    }
    
    private func updateDragPosition(_ x: CGFloat, width: CGFloat) {
        let percent = min(max(x / width, 0), 1)
        dragPosition = percent * duration
    }
}

#Preview {
    ContentView()
        .environmentObject(MediaRemoteAdapter())
}
