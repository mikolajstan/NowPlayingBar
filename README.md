# NowPlayingBar

A small macOS menu bar app that shows the track that is currently playing and lets you control it.

## Features

- Shows tiny artwork and "Title - Artist" in the menu bar, smoothly scrolling when it is too long to fit, and dimmed while paused. A music note is shown when nothing is playing.
- Click it to open a popover with artwork, title, artist, album and the app that's playing, over a blurred copy of the artwork.
- Seek bar with elapsed and total time. Click or drag it to seek.
- Previous, play/pause and next buttons.
- "Up next": the next songs in the queue of the YouTube Music web app, under the playback controls.
- Settings for the width, background, text color and paused look of the menu bar item and the layout and colors of the popover, with quick settings inside the popover.
- Click the app name in the popover to bring the playing app (or browser tab) forward.
- Shortcuts while the popover is open: ⌘, for settings, ⌘W or Esc to close, ⌘Q to quit.
- Works with anything that reports to macOS's Now Playing, including browser players such as YouTube Music in Safari or Chrome, as well as Music, Spotify and others. By default only music.youtube.com is shown; allowed domains and apps can be changed in Settings > Sources.
- Runs only in the menu bar, with no Dock icon, and only one copy at a time.

## How it works

Since macOS 15.4, apps can no longer read the system's Now Playing info directly. NowPlayingBar uses [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), which works around this by running through `/usr/bin/perl`.

The adapter is bundled inside the app, so nothing needs to be installed separately. Its source lives in `Vendor/mediaremote-adapter`, and `Scripts/build-mediaremote-adapter.sh` compiles it into the app during the build. At launch the app runs the adapter's self-test and shows an error in the popover if it fails.

Sources are filtered by domain. The adapter only reports which app is playing, so the domain of a web app (for example a YouTube Music app made with Safari's Add to Dock) is read from the app's Info.plist. For a regular browser tab, the app asks Safari or a Chrome-based browser over AppleScript which tab is playing, which needs a one-time Automation permission.

The Now Playing info in macOS doesn't include the queue for web players, so "Up next" reads it from the YouTube Music web app's page through the Accessibility API. This needs the Accessibility permission (Privacy & Security > Accessibility), and YouTube Music only puts the queue on the page once its player page has been opened. Browser tabs aren't supported yet.

## Requirements

- macOS 26.2 or later
- Xcode, to build it

## Building

1. Clone the repository and open `NowPlayingBar.xcodeproj` in Xcode.
2. Select the NowPlayingBar scheme and press Run (⌘R).

## Installing

1. In Xcode, choose **Product > Archive**.
2. In the Organizer, select the archive and click **Distribute App**, then **Copy App**.
3. Move the exported `NowPlayingBar.app` into `/Applications`.

The app is not signed with a Developer ID or notarized, so macOS may block it the first time you open it. If that happens, open **System Settings > Privacy & Security**, scroll down to the message about NowPlayingBar and click **Open Anyway**.

## Credits

Now Playing data and playback control come from [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) by Jonas van den Berg and contributors, used under the BSD 3-Clause License. See `Vendor/mediaremote-adapter/LICENSE`.
