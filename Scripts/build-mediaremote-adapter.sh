#!/bin/bash
#
# Builds the vendored mediaremote-adapter framework and test client and
# bundles them, together with the Perl script, inside the app. Runs as an
# Xcode build phase.
#
#   Contents/Frameworks/MediaRemoteAdapter.framework
#   Contents/MacOS/MediaRemoteAdapterTestClient   (used by the `test` command)
#   Contents/Resources/mediaremote-adapter.pl
#   Contents/Resources/adapter-command-server.pl  (playback commands)
#
# The app never links the framework. It runs
# `/usr/bin/perl mediaremote-adapter.pl MediaRemoteAdapter.framework <command>`,
# and Perl loads the framework itself (see Vendor/mediaremote-adapter/VENDORED.md).

set -euo pipefail

ADAPTER_DIR="${SRCROOT}/Vendor/mediaremote-adapter"
NAME="MediaRemoteAdapter"
FRAMEWORK="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/${NAME}.framework"
RESOURCES="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
TEST_CLIENT="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}/${NAME}TestClient"
SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"

# Keep in sync with ADAPTER_SOURCES in upstream's CMakeLists.txt
SOURCES=(
    src/adapter/env.m
    src/adapter/get.m
    src/adapter/globals.m
    src/adapter/keys.m
    src/adapter/now_playing.m
    src/adapter/repeat.m
    src/adapter/seek.m
    src/adapter/send.m
    src/adapter/shuffle.m
    src/adapter/speed.m
    src/adapter/stream.m
    src/adapter/test.m
    src/private/MediaRemote.m
    src/utility/Debounce.m
    src/utility/helpers.m
)

ARCH_FLAGS=()
for arch in ${ARCHS}; do
    ARCH_FLAGS+=(-arch "${arch}")
done

# Versioned framework layout, as upstream's CMake build produces
rm -rf "${FRAMEWORK}"
mkdir -p "${FRAMEWORK}/Versions/A/Resources"
ln -s A "${FRAMEWORK}/Versions/Current"
ln -s "Versions/Current/${NAME}" "${FRAMEWORK}/${NAME}"
ln -s Versions/Current/Resources "${FRAMEWORK}/Resources"

cd "${ADAPTER_DIR}"

# -fvisibility=default: the Perl script looks up the framework's functions by name
xcrun clang "${ARCH_FLAGS[@]}" \
    -mmacosx-version-min="${MACOSX_DEPLOYMENT_TARGET}" \
    -dynamiclib -fobjc-arc -fvisibility=default -O2 \
    -Iinclude -Isrc \
    -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
    -install_name "@rpath/${NAME}.framework/Versions/A/${NAME}" \
    "${SOURCES[@]}" \
    -o "${FRAMEWORK}/Versions/A/${NAME}"

cat > "${FRAMEWORK}/Versions/A/Resources/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${PRODUCT_BUNDLE_IDENTIFIER}.${NAME}</string>
    <key>CFBundleName</key>
    <string>${NAME}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
</dict>
</plist>
EOF

mkdir -p "$(dirname "${TEST_CLIENT}")"
xcrun clang "${ARCH_FLAGS[@]}" \
    -mmacosx-version-min="${MACOSX_DEPLOYMENT_TARGET}" \
    -fobjc-arc -O2 \
    -Isrc/test \
    -framework Foundation -framework MediaPlayer \
    src/test/main.m src/test/NowPlayingTest.m \
    -o "${TEST_CLIENT}"

# Nested code must be signed before Xcode signs the app.
# "-" (ad hoc) when the target signs to run locally.
codesign --force --options runtime --timestamp=none \
    --sign "${SIGN_IDENTITY}" \
    "${FRAMEWORK}" "${TEST_CLIENT}"

mkdir -p "${RESOURCES}"
cp "${ADAPTER_DIR}/bin/mediaremote-adapter.pl" "${RESOURCES}/"
cp "${SRCROOT}/Scripts/adapter-command-server.pl" "${RESOURCES}/"
