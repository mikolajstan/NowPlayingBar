# mediaremote-adapter (vendored)

Source copied from https://github.com/ungive/mediaremote-adapter at commit
`0e82bf1c44ec39554fbfc402ec88a48c6ae2a0fd` (2026-10-17). BSD 3-Clause, see `LICENSE`.

Kept: `bin/mediaremote-adapter.pl`, `include/` and `src/`. The framework build
needs the header in `src/test`; the test client sources there are not compiled.

The framework is not built with upstream's CMake setup. Instead the
"Bundle mediaremote-adapter" build phase runs `Scripts/build-mediaremote-adapter.sh`,
which compiles these sources with clang into
`NowPlayingBar.app/Contents/Frameworks/MediaRemoteAdapter.framework` and copies the
Perl script into `Contents/Resources`.

To update: copy `bin/`, `include/`, `src/` and `LICENSE` from a newer upstream checkout, update the commit above, and check
upstream's `CMakeLists.txt` for new source files or linked frameworks.
