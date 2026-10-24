//
//  NowPlayingBarApp.swift
//  NowPlayingBar
//
//  Created by miki on 14/10/2026.
//

import SwiftUI

@main
struct NowPlayingBarApp: App {
    @StateObject private var adapter: MediaRemoteAdapter
    @State private var scrollOffset: Int = 0
    @State private var scrollTimer: Timer?

    init() {
        // Start streaming at launch so the menu bar title shows without opening the popover
        let adapter = MediaRemoteAdapter()
        adapter.start()
        _adapter = StateObject(wrappedValue: adapter)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(adapter)
        } label: {
            if let info = adapter.nowPlaying {
                Text(scrollingText(info))
                    .monospacedDigit() // Helps with smoother scrolling
                    .onChange(of: info.title) { oldValue, newValue in
                        // Reset scroll when song changes
                        scrollOffset = 0
                    }
            } else {
                Image(systemName: "music.note")
            }
        }
        .menuBarExtraStyle(.window)
        .onChange(of: adapter.nowPlaying) { oldValue, newValue in
            // Start or stop scrolling based on whether something is playing
            if newValue != nil {
                startScrolling()
            } else {
                stopScrolling()
            }
        }
    }
    
    // MARK: - Scrolling Logic
    
    private func scrollingText(_ info: NowPlayingInfo) -> String {
        let title = info.title ?? "Unknown"
        let artist = info.artist ?? "Unknown"
        let combined = "\(title) - \(artist)"
        
        let maxLength = 40 // Maximum characters to show at once
        
        // If the text is short enough, just return it
        if combined.count <= maxLength {
            return combined
        }
        
        // Add separator and padding for seamless loop
        let separator = "   •   "
        let padded = combined + separator
        
        // Create a seamless loop by repeating the text
        let loopText = padded + padded
        
        // Calculate the visible window
        let startOffset = scrollOffset % padded.count
        let startIndex = loopText.index(loopText.startIndex, offsetBy: startOffset)
        
        // Make sure we don't go past the end
        let maxEndOffset = min(startOffset + maxLength, loopText.count)
        let endIndex = loopText.index(loopText.startIndex, offsetBy: maxEndOffset)
        
        return String(loopText[startIndex..<endIndex])
    }
    
    private func startScrolling() {
        // Don't start multiple timers
        guard scrollTimer == nil else { return }
        
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            scrollOffset += 1
        }
    }
    
    private func stopScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        scrollOffset = 0
    }
}
