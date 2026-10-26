//
//  SettingsView.swift
//  NowPlayingBar
//

import SwiftUI

/// Settings window: look of the menu bar item and popover, and which sources to show
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            Tab("Menu Bar", systemImage: "menubar.rectangle") {
                MenuBarSettings()
            }
            Tab("Popover", systemImage: "rectangle.on.rectangle") {
                PopoverSettings()
            }
            Tab("Sources", systemImage: "line.3.horizontal.decrease.circle") {
                SourceSettings()
            }
        }
        .frame(width: 480, height: 520)
    }
}

// MARK: - Menu Bar

private struct MenuBarSettings: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Layout") {
                LabeledSlider("Width", value: $settings.menuBarWidth, in: 80...500, step: 10, unit: "pt")
                Toggle("Shrink to fit short titles", isOn: $settings.menuBarShrinkToFit)
                Toggle("Show artwork before the title", isOn: $settings.menuBarShowArtwork)
                Toggle("Show artist", isOn: $settings.menuBarShowArtist)
                Toggle("Custom text color", isOn: $settings.menuBarTextColorEnabled)
                ColorPicker("Text color", selection: $settings.menuBarTextColor)
                    .disabled(!settings.menuBarTextColorEnabled)
                LabeledSlider("Scroll speed", value: $settings.menuBarScrollSpeed, in: 0...100, step: 5, unit: "pt/s")
            }

            Section("Background") {
                Toggle("Show background", isOn: $settings.menuBarBackgroundEnabled)
                LabeledSlider("Horizontal padding", value: $settings.menuBarHorizontalPadding, in: 0...20, step: 1, unit: "pt")
                LabeledSlider("Vertical inset", value: $settings.menuBarBackgroundInset, in: 0...6, step: 1, unit: "pt")
                    .disabled(!settings.menuBarBackgroundEnabled)
                ColorPicker("Color", selection: $settings.menuBarBackgroundColor, supportsOpacity: false)
                    .disabled(!settings.menuBarBackgroundEnabled)
                LabeledSlider("Opacity", value: $settings.menuBarBackgroundOpacity, in: 0...1, step: 0.05, percent: true)
                    .disabled(!settings.menuBarBackgroundEnabled)
            }

            Section("When paused") {
                LabeledSlider("Artwork and text opacity", value: $settings.menuBarPausedOpacity, in: 0.1...1, step: 0.05, percent: true)
                Toggle("Use a different text color", isOn: $settings.menuBarPausedTintEnabled)
                ColorPicker("Text color", selection: $settings.menuBarPausedColor)
                    .disabled(!settings.menuBarPausedTintEnabled)
            }

            ResetSection()
        }
        .formStyle(.grouped)
    }
}

// MARK: - Popover

private struct PopoverSettings: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Stay open when switching to another app", isOn: $settings.popoverStaysOpen)
            }

            Section("Layout") {
                LabeledSlider("Artwork size", value: $settings.popoverArtworkSize, in: 120...320, step: 10, unit: "pt")
                LabeledSlider("Spacing", value: $settings.popoverSpacing, in: 4...30, step: 1, unit: "pt")
                Picker("Text alignment", selection: $settings.popoverTextAlignment) {
                    Text("Leading").tag(PopoverTextAlignment.leading)
                    Text("Center").tag(PopoverTextAlignment.center)
                }
                .pickerStyle(.segmented)
                Toggle("Show album", isOn: $settings.popoverShowAlbum)
                Picker("Source label", selection: $settings.sourceLabelStyle) {
                    ForEach(SourceLabelStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
            }

            Section("Background") {
                Toggle("Blurred artwork background", isOn: $settings.popoverBlurredBackground)
                LabeledSlider("Blur", value: $settings.popoverBlurRadius, in: 10...80, step: 5, unit: "pt")
                    .disabled(!settings.popoverBlurredBackground)
                LabeledSlider("Intensity", value: $settings.popoverBackgroundOpacity, in: 0.1...1, step: 0.05, percent: true)
                    .disabled(!settings.popoverBlurredBackground)
            }

            Section {
                Toggle("Show the next songs", isOn: $settings.popoverShowUpNext)
                Stepper("Songs shown: \(settings.popoverUpNextCount)", value: $settings.popoverUpNextCount, in: 1...10)
                    .disabled(!settings.popoverShowUpNext)
            } header: {
                Text("Up next")
            } footer: {
                Text("Read from the YouTube Music web app. Needs Accessibility access, and the queue shows up once its player page has been opened.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Colors") {
                ColorPicker("Button background", selection: $settings.buttonBackgroundColor)
                ColorPicker("Button background on hover", selection: $settings.buttonHoverColor)
                Toggle("Custom button icon color", isOn: $settings.buttonIconColorEnabled)
                ColorPicker("Button icon color", selection: $settings.buttonIconColor)
                    .disabled(!settings.buttonIconColorEnabled)
                ColorPicker("Seek bar", selection: $settings.seekBarColor)
            }

            ResetSection()
        }
        .formStyle(.grouped)
    }
}

// MARK: - Sources

private struct SourceSettings: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var adapter: MediaRemoteAdapter

    @State private var newDomain = ""

    var body: some View {
        Form {
            Section {
                Toggle("Only show allowed sources", isOn: $settings.sourceFilterEnabled)
            } footer: {
                Text("Hides everything else, like videos on youtube.com.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(settings.allowedDomains, id: \.self) { domain in
                    HStack {
                        Text(domain)
                        Spacer()
                        RemoveButton { settings.allowedDomains.removeAll { $0 == domain } }
                    }
                }
                HStack {
                    TextField("Add domain", text: $newDomain, prompt: Text("e.g. open.spotify.com"))
                        .labelsHidden()
                        .onSubmit(addDomain)
                    Button("Add", action: addDomain)
                        .disabled(cleanedDomain.isEmpty)
                }
            } header: {
                Text("Allowed domains")
            } footer: {
                Text("Matched against web apps (like the YT Music app) and, as a fallback, the browser tab that's playing. Subdomains are included.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.sourceFilterEnabled)

            Section {
                ForEach(settings.allowedApps, id: \.self) { bundleID in
                    HStack {
                        AppRow(bundleID: bundleID)
                        Spacer()
                        RemoveButton { settings.allowedApps.removeAll { $0 == bundleID } }
                    }
                }
                if settings.allowedApps.isEmpty {
                    Text("No apps")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Allowed apps")
            } footer: {
                Text("For apps without a domain, like Music or Spotify.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.sourceFilterEnabled)

            Section {
                Toggle("Check the browser tab that's playing", isOn: $settings.browserTabLookupEnabled)
            } footer: {
                Text("For Safari and Chrome-based browsers. macOS asks once for permission to control the browser.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.sourceFilterEnabled)

            Section("Playing now") {
                if let info = adapter.unfilteredNowPlaying, let bundleID = info.sourceApp {
                    LabeledContent {
                        Text(adapter.nowPlaying == nil ? "Hidden" : "Shown")
                            .foregroundStyle(adapter.nowPlaying == nil ? .orange : .green)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            AppRow(bundleID: bundleID)
                            if let domain = adapter.sourceDomain {
                                Text(domain)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        if let domain = adapter.sourceDomain {
                            Button("Allow \(domain)") {
                                settings.allowedDomains.append(domain)
                            }
                            .disabled(settings.allowedDomains.contains(domain))
                        }
                        Button("Allow this app") {
                            settings.allowedApps.append(bundleID)
                        }
                        .disabled(settings.allowedApps.contains(bundleID))
                    }
                } else {
                    Text("Nothing playing")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// Host part of whatever was typed (a pasted URL works too)
    private var cleanedDomain: String {
        let text = newDomain.trimmingCharacters(in: .whitespaces).lowercased()
        return URL(string: text)?.host() ?? text
    }

    private func addDomain() {
        let domain = cleanedDomain
        guard !domain.isEmpty, !settings.allowedDomains.contains(domain) else { return }
        settings.allowedDomains.append(domain)
        newDomain = ""
    }
}

/// App icon and name for a bundle ID (falls back to the ID)
private struct AppRow: View {
    let bundleID: String

    var body: some View {
        let app = SourceApp.lookup(bundleID)
        HStack(spacing: 6) {
            if let icon = app?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
            }
            Text(app?.name ?? bundleID)
        }
        .help(bundleID)
    }
}

private struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Remove")
    }
}

// MARK: - Quick Settings

/// A few common settings inside the popover, with a button to the full settings window
struct QuickSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    var openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Toggle("Artwork in menu bar", isOn: $settings.menuBarShowArtwork)
            Toggle("Artist in menu bar", isOn: $settings.menuBarShowArtist)
            Toggle("Blurred background", isOn: $settings.popoverBlurredBackground)
            LabeledSlider("Menu bar width", value: $settings.menuBarWidth, in: 80...500, step: 10, unit: "pt")
            LabeledSlider("Artwork size", value: $settings.popoverArtworkSize, in: 120...320, step: 10, unit: "pt")

            HStack {
                Spacer()
                Button("All Settings…", action: openSettings)
            }
        }
        .toggleStyle(QuickToggleStyle())
        .controlSize(.small)
        .font(.caption)
    }
}

/// Label on the left, a mini switch on the right, so the switch matches the caption-sized text
private struct QuickToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Toggle("", isOn: configuration.$isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }
}

// MARK: - Shared

private struct ResetSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Section {
            HStack {
                Spacer()
                Button("Restore Defaults") {
                    settings.resetToDefaults()
                }
            }
        }
    }
}

/// Slider with its label and current value
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var unit: String = ""
    var percent = false

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, unit: String = "", percent: Bool = false) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.percent = percent
    }

    var body: some View {
        LabeledContent(title) {
            HStack {
                // No `step:`, which would draw a tick mark for every step
                Slider(
                    value: Binding(
                        get: { value },
                        set: { value = (($0 / step).rounded() * step).clamped(to: range) }
                    ),
                    in: range
                )
                Text(formatted)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }

    private var formatted: String {
        percent ? "\(Int((value * 100).rounded()))%" : "\(Int(value.rounded())) \(unit)"
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
