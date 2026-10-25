# NowPlayingBar

A small macOS menu bar app that shows the track that is currently playing and lets you control it.

## Features

- Shows "Title - Artist" in the menu bar, scrolling when it is too long to fit. A music note is shown when nothing is playing.
- Click it to open a popover with artwork, title, artist and album.
- Progress bar with elapsed and total time. Click or drag it to seek.
- Previous, play/pause and next buttons.
- Works with anything that reports to macOS's Now Playing, including browser players such as YouTube Music in Safari or Chrome, as well as Music, Spotify and others.
- Runs only in the menu bar, with no Dock icon.

## How it works

Since macOS 15.4, apps can no longer read the system's Now Playing info directly. NowPlayingBar uses [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), which works around this by running through `/usr/bin/perl`.

The adapter is bundled inside the app, so nothing needs to be installed separately. Its source lives in `Vendor/mediaremote-adapter`, and `Scripts/build-mediaremote-adapter.sh` compiles it into the app during the build. At launch the app runs the adapter's self-test and shows an error in the popover if it fails.

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
