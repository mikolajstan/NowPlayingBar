# Changelog

## Unreleased

- App icon.
- "Up next" in the popover: the next songs in the YouTube Music web app's queue, read through Accessibility. It can be turned off and the number of songs set in Settings > Popover.

## 1.1 - 2026-10-25

### Menu bar
- Stable width (or shrink to fit) with smooth scrolling for long titles, which loops seamlessly and keeps going while paused.
- Tiny artwork before the title, an optional background with its own color, opacity, padding and height, and a custom text color.
- Paused tracks dim the artwork and text (or use a different text color), leaving the background as it is.

### Popover
- Opens under the right edge of the menu bar item and keeps its position and size. Optionally stays open when you switch to another app.
- Blurred artwork background, with text and controls switching between light and dark to stay readable over bright artwork.
- Fixed-size artwork with a matching placeholder, rounded corners and a softer shadow, plus crossfades between tracks.
- Round playback buttons that highlight and grow on hover and shrink when pressed, with a faint border and icons that pick black or white to match the button color.
- Seek bar that reacts to clicks anywhere on it (on the first click), grows on hover and shows a knob and the time under the cursor, with elapsed and total time at its ends.
- The playing app's icon and name at the top; click it to bring that app (or browser tab) forward.
- Instant feedback on next/previous: the artwork dims with a spinner and the progress resets until the new track arrives.
- Quit button (power icon), plus ⌘, for settings, ⌘W or Esc to close and ⌘Q to quit.
- Nicer "Nothing playing", loading and error states.

### Settings
- Settings window (gear button) for the menu bar item, the popover's layout and colors, and sources, plus quick settings inside the popover. Esc or ⌘W closes it, and the popover stays open beside it while you adjust things.

### Sources
- Only allowed sources are shown, by default music.youtube.com, so YouTube videos stay out of the menu bar. The domain comes from the web app (e.g. YouTube Music added to the Dock from Safari) or, for a plain browser tab, from Safari or a Chrome-based browser.
- Allowed domains and apps can be edited in Settings > Sources.

### Fixes
- Only one copy of the app runs at a time; opening it again shows the running copy's popover.
- Titles with HTML entities such as "&amp;" show the actual character.
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
