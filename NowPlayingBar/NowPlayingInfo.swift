//
//  NowPlayingInfo.swift
//  NowPlayingBar
//
//  Created by miki on 14/10/2026.
//

import Foundation
import AppKit

/// Represents the now playing information from MediaRemote
struct NowPlayingInfo: Codable, Equatable {
    // MARK: - Track Information
    
    /// The title of the currently playing track
    let title: String?
    
    /// The artist name
    let artist: String?
    
    /// The album name
    let album: String?
    
    // MARK: - Playback State
    
    /// Whether the track is currently playing (true) or paused (false)
    let playing: Bool?
    
    /// Current playback position in seconds
    let elapsedTime: Double?
    
    /// Total duration of the track in seconds
    let duration: Double?
    
    /// Playback rate (1.0 = normal speed, 2.0 = 2x, etc.)
    let playbackRate: Double?
    
    // MARK: - Artwork
    
    /// Base64-encoded artwork data (typically JPEG or PNG)
    let artworkData: String?
    
    /// MIME type of the artwork (e.g., "image/jpeg")
    let artworkMimeType: String?
    
    // MARK: - Application Information
    
    /// Bundle identifier of the app providing the media (may be GPU process)
    let bundleIdentifier: String?
    
    /// Bundle identifier of the parent application (the actual app, e.g., Safari web app)
    let parentApplicationBundleIdentifier: String?
    
    /// Process identifier
    let processIdentifier: Int?
    
    // MARK: - Track Identifiers
    
    /// Unique identifier for the track
    let uniqueIdentifier: Int?
    
    /// Content item identifier (often same as uniqueIdentifier)
    let contentItemIdentifier: String?
    
    /// Timestamp when this information was captured
    let timestamp: String?
    
    // MARK: - Computed Properties
    
    /// The actual app providing the media (prefers parent bundle ID)
    var sourceApp: String? {
        parentApplicationBundleIdentifier ?? bundleIdentifier
    }
    
    /// Whether this is likely from YouTube Music
    var isYouTubeMusic: Bool {
        guard let sourceApp = sourceApp else { return false }
        return sourceApp.contains("Safari.WebApp")
    }
    
    /// Title, artist and album with HTML entities decoded (web players send e.g. "&amp;")
    var displayTitle: String? { title.map(Self.decodeEntities) }
    var displayArtist: String? { artist.map(Self.decodeEntities) }
    var displayAlbum: String? { album.map(Self.decodeEntities) }
    
    /// Elapsed time right now. The adapter reports `elapsedTime` as of `timestamp`,
    /// so while playing we add the time that has passed since then.
    var currentElapsedTime: Double {
        guard let elapsed = elapsedTime else { return 0 }
        guard playing == true,
              let timestamp = timestamp,
              let date = Self.timestampFormatter.date(from: timestamp) else {
            return elapsed
        }
        let now = max(elapsed + Date().timeIntervalSince(date) * (playbackRate ?? 1.0), 0)
        if let duration = duration, duration > 0 {
            return min(now, duration)
        }
        return now
    }
    
    /// Formatted elapsed time (e.g., "1:23")
    var formattedElapsedTime: String {
        guard let elapsed = elapsedTime else { return "0:00" }
        return formatTime(elapsed)
    }
    
    /// Formatted duration (e.g., "3:45")
    var formattedDuration: String {
        guard let duration = duration else { return "0:00" }
        return formatTime(duration)
    }
    
    /// Progress as a percentage (0.0 to 1.0)
    var progress: Double {
        guard let elapsed = elapsedTime,
              let duration = duration,
              duration > 0 else {
            return 0
        }
        return elapsed / duration
    }
    
    // MARK: - Private Helpers
    
    /// Parses the adapter's timestamp format (e.g., "2026-10-24T13:04:20Z")
    private static let timestampFormatter = ISO8601DateFormatter()
    
    /// `&amp;` last, so "&amp;lt;" becomes "&lt;" and not "<"
    nonisolated private static let entities = [
        ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&amp;", "&"),
    ]
    
    nonisolated private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        for (entity, character) in entities {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
