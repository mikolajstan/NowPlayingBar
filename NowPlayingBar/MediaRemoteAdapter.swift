//
//  MediaRemoteAdapter.swift
//  NowPlayingBar
//
//  Created by miki on 14/10/2026.
//

import Foundation
import Combine
import AppKit

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
    
    /// Decoded artwork for `nowPlaying`, only re-decoded when the artwork data changes
    @Published var artwork: NSImage?
    
    /// True from a next/previous click until the stream reports the change
    /// (or a short timeout passes), so the UI can react before the round trip
    @Published var isChangingTrack: Bool = false
    
    // MARK: - Private Properties
    
    private var process: Process?
    private var outputPipe: Pipe?
    
    /// Path to the Perl script
    private let scriptPath: String
    
    /// Path to the framework
    private let frameworkPath: String
    
    /// Path to the test client used by the adapter's `test` command
    private let testClientPath: String
    
    /// Whether the startup `test` command is still running
    private var isTesting = false
    
    /// Path to adapter-command-server.pl, which runs playback commands
    private let commandServerPath: String
    
    /// Long-lived command server and the pipe used to send it commands
    private var commandProcess: Process?
    private var commandInput: FileHandle?
    
    /// Track shown when next/previous was clicked, and the timeout for `isChangingTrack`
    private var trackBeforeChange: NowPlayingInfo?
    private var trackChangeTimeout: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// Initialize with paths to the adapter script and framework
    /// - Parameters:
    ///   - scriptPath: Path to mediaremote-adapter.pl
    ///   - frameworkPath: Path to MediaRemoteAdapter.framework
    ///   - testClientPath: Path to MediaRemoteAdapterTestClient
    ///   - commandServerPath: Path to adapter-command-server.pl
    init(scriptPath: String, frameworkPath: String, testClientPath: String, commandServerPath: String) {
        self.scriptPath = scriptPath
        self.frameworkPath = frameworkPath
        self.testClientPath = testClientPath
        self.commandServerPath = commandServerPath
        
        // Writing to a command server that has exited must throw, not kill the app
        signal(SIGPIPE, SIG_IGN)
    }
    
    /// Convenience initializer using the copy bundled inside the app
    /// (built by Scripts/build-mediaremote-adapter.sh)
    convenience init() {
        let bundle = Bundle.main

        self.init(
            scriptPath: bundle.url(forResource: "mediaremote-adapter", withExtension: "pl")?.path ?? "",
            frameworkPath: bundle.privateFrameworksURL?
                .appendingPathComponent("MediaRemoteAdapter.framework").path ?? "",
            testClientPath: bundle.url(forAuxiliaryExecutable: "MediaRemoteAdapterTestClient")?.path ?? "",
            commandServerPath: bundle.url(forResource: "adapter-command-server", withExtension: "pl")?.path ?? ""
        )
    }
    
    // MARK: - Public Methods
    
    /// Check that the adapter works on this macOS version, then start streaming
    func start() {
        guard !isRunning, !isTesting else {
            print("⚠️ Adapter already running")
            return
        }
        
        print("🧪 Testing mediaremote-adapter...")
        isTesting = true
        
        let test = Process()
        test.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        test.arguments = [scriptPath, frameworkPath, testClientPath, "test"]
        test.standardOutput = FileHandle.nullDevice
        test.standardError = FileHandle.nullDevice
        test.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { @MainActor in
                self?.finishTest(status: status)
            }
        }
        
        do {
            try test.run()
        } catch {
            print("❌ Failed to run adapter test: \(error)")
            isTesting = false
            lastError = "Failed to start: \(error.localizedDescription)"
        }
    }
    
    /// Start streaming if the `test` command succeeded (exit code 0)
    private func finishTest(status: Int32) {
        isTesting = false
        
        guard status == 0 else {
            print("❌ Adapter test failed with exit code \(status)")
            lastError = "Now playing info isn't available on this macOS version"
            return
        }
        
        startStream()
        
        // Start the command server now so the first click doesn't wait for it
        startCommandServer()
    }
    
    /// Start streaming now playing information
    private func startStream() {
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
        stopCommandServer()
        
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
        if command == .nextTrack || command == .previousTrack {
            beginTrackChange()
        }
        runCommand(["send", String(command.rawValue)])
    }
    
    /// Seek to a position in the current track
    /// - Parameter seconds: Position in seconds (the adapter expects microseconds)
    func seek(to seconds: Double) {
        let micros = Int((max(seconds, 0) * 1_000_000).rounded())
        runCommand(["seek", String(micros)])
    }
    
    /// Send a command to the command server, restarting it once if it has exited.
    /// Falls back to a one-shot adapter process if the server can't be used.
    private func runCommand(_ arguments: [String]) {
        let line = Data((arguments.joined(separator: " ") + "\n").utf8)
        
        for attempt in 0..<2 {
            if attempt > 0 || commandProcess?.isRunning != true {
                startCommandServer()
            }
            guard let input = commandInput else { break }
            do {
                try input.write(contentsOf: line)
                print("✅ Sent command: \(arguments.joined(separator: " "))")
                return
            } catch {
                print("⚠️ Command server write failed: \(error)")
                stopCommandServer()
            }
        }
        
        runOneShotCommand(arguments)
    }
    
    /// Start (or restart) adapter-command-server.pl, which loads the framework once
    private func startCommandServer() {
        stopCommandServer()
        guard !commandServerPath.isEmpty else { return }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [commandServerPath, frameworkPath]
        let input = Pipe()
        task.standardInput = input
        task.standardOutput = FileHandle.nullDevice
        
        do {
            try task.run()
            commandProcess = task
            commandInput = input.fileHandleForWriting
        } catch {
            print("❌ Failed to start command server: \(error)")
        }
    }
    
    private func stopCommandServer() {
        try? commandInput?.close()
        commandInput = nil
        if commandProcess?.isRunning == true {
            commandProcess?.terminate()
        }
        commandProcess = nil
    }
    
    /// Run a one-shot adapter command (separate from the stream process)
    private func runOneShotCommand(_ arguments: [String]) {
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
    
    // MARK: - Track Change Feedback
    
    /// Remember the current track and show the "changing" state until it changes
    private func beginTrackChange() {
        trackBeforeChange = nowPlaying
        isChangingTrack = true
        
        trackChangeTimeout?.cancel()
        trackChangeTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.endTrackChange()
        }
    }
    
    private func endTrackChange() {
        trackChangeTimeout?.cancel()
        trackChangeTimeout = nil
        trackBeforeChange = nil
        isChangingTrack = false
    }
    
    /// Apply a stream update on the main actor
    private func update(_ info: NowPlayingInfo?) {
        if info?.artworkData != nowPlaying?.artworkData || (artwork == nil && info?.artworkData != nil) {
            artwork = info?.artworkData
                .flatMap { Data(base64Encoded: $0) }
                .flatMap { NSImage(data: $0) }
        }
        
        if isChangingTrack, let before = trackBeforeChange {
            // A new track, or "previous" restarting the same one
            let changed = info?.uniqueIdentifier != before.uniqueIdentifier
                || info?.title != before.title
                || (info?.elapsedTime ?? 0) < before.currentElapsedTime - 1
            if changed {
                endTrackChange()
            }
        }
        
        nowPlaying = info
        lastError = nil
    }
    
    // MARK: - Private Methods
    
    /// Read and parse output from the adapter until the process exits
    nonisolated private func readOutput(from pipe: Pipe) async {
        let fileHandle = pipe.fileHandleForReading
        
        // Buffer for accumulating data
        var buffer = Data()
        
        while true {
            // Blocks until data arrives; empty means the process ended (or was stopped)
            let data = fileHandle.availableData
            
            if data.isEmpty {
                await MainActor.run {
                    // Ignore if a newer stream has replaced this one
                    if self.outputPipe === pipe {
                        self.isRunning = false
                    }
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
        
        // Try to decode as NowPlayingInfo
        let decoder = JSONDecoder()
        
        do {
            let response = try decoder.decode(AdapterResponse.self, from: data)
            let info = response.payload
            
            // Update on main thread
            await MainActor.run {
                self.update(info)
            }
            
            print("🎵 Updated: \(info.title ?? "Uknown") - \(info.artist ?? "Unknown")")
        } catch {
            // Could be null or an error message
            if let jsonString = String(data: data, encoding: .utf8) {
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
                    // Nothing playing
                    await MainActor.run {
                        self.update(nil)
                    }
                    print("⏸️ Nothing playing")
                } else {
                    // Don't print the whole line: it can hold hundreds of KB of artwork
                    print("⚠️ Failed to decode JSON: \(error)")
                    print("📄 Raw: \(jsonString.prefix(500))")
                }
            }
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        process?.terminate()
        commandProcess?.terminate()
    }
}
