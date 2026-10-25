# Changelog

## Unreleased

- Instant feedback on next/previous: buttons react when pressed, the artwork dims with a spinner and the progress bar resets until the new track arrives.
- Artwork is decoded once per track instead of on every redraw, and the full JSON of each update is no longer logged.

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
