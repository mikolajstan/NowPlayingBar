//
//  MediaRemoteAdapter.swift
//  NowPlayingBar
//
//  Created by miki on 14/10/2026.
//

import Foundation
import Combine

/// Wrapper for the adapter's JSON response
private struct AdapterResponse: Codable {
    let type: String
    let diff: Bool
    let payload: NowPlayingInfo
}

/// Manages communication with the mediaremote-adapter subprocess
@MainActor
class MediaRemoteAdapter: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The current now playing information (nil if nothing is playing)
    @Published var nowPlaying: NowPlayingInfo?
    
    /// Whether the adapter is currently running
    @Published var isRunning: Bool = false
    
    /// Last error message, if any
    @Published var lastError: String?
    
    // MARK: - Private Properties
    
    private var process: Process?
    private var outputPipe: Pipe?
    
    /// Path to the Perl script
    private let scriptPath: String
    
    /// Path to the framework
    private let frameworkPath: String
    
    // MARK: - Initialization
    
    /// Initialize with paths to the adapter script and framework
    /// - Parameters:
    ///   - scriptPath: Path to mediaremote-adapter.pl
    ///   - frameworkPath: Path to MediaRemoteAdapter.framework
    init(scriptPath: String, frameworkPath: String) {
        self.scriptPath = scriptPath
        self.frameworkPath = frameworkPath
    }
    
    /// Convenience initializer using the copy bundled inside the app
    /// (built by Scripts/build-mediaremote-adapter.sh)
    convenience init() {
        let bundle = Bundle.main

        self.init(
            scriptPath: bundle.url(forResource: "mediaremote-adapter", withExtension: "pl")?.path ?? "",
            frameworkPath: bundle.privateFrameworksURL?
                .appendingPathComponent("MediaRemoteAdapter.framework").path ?? ""
        )
    }
    
    // MARK: - Public Methods
    
    /// Start streaming now playing information
    func start() {
        guard !isRunning else {
            print("⚠️ Adapter already running")
            return
        }
        
        print("🚀 Starting mediaremote-adapter...")
        
        // Create the process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptPath, frameworkPath, "stream", "--no-diff"]
        
        // Set up pipe to capture output
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        // Store references
        self.process = process
        self.outputPipe = pipe
        
        // Start reading output in the background
        let adapter = self
        Task.detached {
            await adapter.readOutput(from: pipe)
        }
        
        // Start the process
        do {
            try process.run()
            self.isRunning = true
            self.lastError = nil
            print("✅ Adapter started")
        } catch {
            print("❌ Failed to start adapter: \(error)")
            self.lastError = "Failed to start: \(error.localizedDescription)"
        }
    }
    
    /// Stop the adapter
    func stop() {
        guard isRunning else { return }
        
        print("🛑 Stopping mediaremote-adapter...")
        
        process?.terminate()
        process = nil
        outputPipe = nil
        isRunning = false
        
        print("✅ Adapter stopped")
    }
    
    // MARK: - Playback Commands
    
    /// MediaRemote command IDs accepted by the adapter's `send` command
    enum Command: Int {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case nextTrack = 4
        case previousTrack = 5
    }
    
    /// Send a playback command to the now playing application
    func send(_ command: Command) {
        runCommand(["send", String(command.rawValue)])
    }
    
    /// Seek to a position in the current track
    /// - Parameter seconds: Position in seconds (the adapter expects microseconds)
    func seek(to seconds: Double) {
        let micros = Int((max(seconds, 0) * 1_000_000).rounded())
        runCommand(["seek", String(micros)])
    }
    
    /// Run a one-shot adapter command (separate from the stream process)
    private func runCommand(_ arguments: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [scriptPath, frameworkPath] + arguments
        
        do {
            try task.run()
            print("✅ Sent command: \(arguments.joined(separator: " "))")
        } catch {
            print("❌ Failed to send command: \(error)")
            lastError = "Failed to send command: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Methods
    
    /// Read and parse output from the adapter
    nonisolated private func readOutput(from pipe: Pipe) async {
        let fileHandle = pipe.fileHandleForReading
        
        // Buffer for accumulating data
        var buffer = Data()
        
        while true {
            // Check if we should stop
            let shouldContinue = await MainActor.run { self.isRunning }
            guard shouldContinue else { break }
            
            // Read available data
            let data = fileHandle.availableData
            
            if data.isEmpty {
                // Process ended
                await MainActor.run {
                    self.isRunning = false
                }
                break
            }
            
            buffer.append(data)
            
            // Process complete lines
            while let newlineRange = buffer.range(of: Data([0x0A])) { // 0x0A = '\n'
                let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
                buffer.removeSubrange(0..<newlineRange.upperBound)
                
                // Parse the line
                await parseLine(lineData)
            }
        }
        
        print("📡 Output reader finished")
    }
    
    /// Parse a single JSON line
    nonisolated private func parseLine(_ data: Data) async {
        guard !data.isEmpty else { return }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 Raw JSON: \(jsonString)")
        }
        
        // Try to decode as NowPlayingInfo
        let decoder = JSONDecoder()
        
        do {
            let response = try decoder.decode(AdapterResponse.self, from: data)
            let info = response.payload
            
            // Update on main thread
            await MainActor.run {
                self.nowPlaying = info
                self.lastError = nil
            }
            
            print("🎵 Updated: \(info.title ?? "Uknown") - \(info.artist ?? "Unknown")")
        } catch {
            // Could be null or an error message
            if let jsonString = String(data: data, encoding: .utf8) {
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
                    // Nothing playing
                    await MainActor.run {
                        self.nowPlaying = nil
                        self.lastError = nil
                    }
                    print("⏸️ Nothing playing")
                } else {
                    print("⚠️ Failed to decode JSON: \(error)")
                    print("📄 Raw: \(jsonString)")
                }
            }
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        process?.terminate()
    }
}
