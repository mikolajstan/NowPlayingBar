# Changelog

## Unreleased

- Instant feedback on next/previous: buttons react when pressed, the artwork dims with a spinner and the progress bar resets until the new track arrives.
- Quit button (power icon) in the popover, also ⌘Q while it is open. Quitting stops the adapter process too.
- Artwork is decoded once per track instead of on every redraw, and the full JSON of each update is no longer logged.
- Menu bar item with a stable width, smooth pixel-by-pixel scrolling, tiny artwork before the title, an optional background, and a dimmed look while paused.
- The popover opens under the right edge of the menu bar item and keeps its position and size.
- Redesigned popover: blurred artwork background, same-size artwork placeholder, round playback buttons with hover and press feedback, a seek bar that grows on hover with a knob and time preview, times at both ends of the seek bar, the source app's icon and name, and crossfades between tracks.
- The seek bar reacts to clicks anywhere on it, on the first click.
- Settings window (gear button) for the look of the menu bar item and popover, plus quick settings inside the popover.
- Only allowed sources are shown, by default music.youtube.com (YouTube Music web apps, or a browser tab as a fallback), so YouTube videos stay out of the menu bar. Allowed domains and apps can be changed in Settings.
- Titles with HTML entities such as "&amp;" show the actual character.

## 1.0 - 2026-10-24

First release.

- Menu bar title showing the current track as "Title - Artist", scrolling when it is too long, and shown from launch.
- Popover with artwork, title, artist and album.
- Progress bar with elapsed and total time, with click and drag to seek.
- Previous, play/pause and next controls.
- Support for browser players such as YouTube Music, plus Music, Spotify and other Now Playing sources, through mediaremote-adapter.
- mediaremote-adapter bundled inside the app and built from source in `Vendor/`, so no separate install is needed.
- Adapter self-test at launch, with an error shown in the popover if it fails.
- Menu bar only app with no Dock icon.
