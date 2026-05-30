#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

APP_NAME="Open YouTube Music"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🛑 Terminating any running instance of $APP_NAME..."
killall "openytmusic" 2>/dev/null || true

echo "🧹 Cleaning previous build..."
rm -rf "$BUILD_DIR"

echo "📁 Creating App Bundle directory structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "⚙ Compiling Swift Native application..."
swiftc -O -o "$MACOS_DIR/openytmusic" \
  src/swift/ThemeCSS.swift \
  src/swift/WebView.swift \
  src/swift/NowPlayingManager.swift \
  src/swift/TrayManager.swift \
  src/swift/LyricsManager.swift \
  src/swift/LyricsViews.swift \
  src/swift/main.swift \
  -sdk $(xcrun --show-sdk-path) \
  -framework SwiftUI \
  -framework WebKit \
  -framework AppKit \
  -framework Foundation \
  -framework MediaPlayer

echo "📝 Creating Info.plist..."
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>openytmusic</string>
    <key>CFBundleIdentifier</key>
    <string>app.baomi.openytmusic</string>
    <key>CFBundleName</key>
    <string>Open YouTube Music</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/> <!-- Set to true if you want status-bar ONLY without Dock icon -->
</dict>
</plist>
EOF

# Convert PNG icon to macOS .icns natively
if [ -f "src/assets/icon.png" ]; then
    echo "🎨 Building native macOS AppIcon.icns from PNG..."
    mkdir -p AppIcon.iconset
    sips -s format png -z 16 16     src/assets/icon.png --out AppIcon.iconset/icon_16x16.png > /dev/null 2>&1
    sips -s format png -z 32 32     src/assets/icon.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null 2>&1
    sips -s format png -z 32 32     src/assets/icon.png --out AppIcon.iconset/icon_32x32.png > /dev/null 2>&1
    sips -s format png -z 64 64     src/assets/icon.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null 2>&1
    sips -s format png -z 128 128   src/assets/icon.png --out AppIcon.iconset/icon_128x128.png > /dev/null 2>&1
    sips -s format png -z 256 256   src/assets/icon.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null 2>&1
    sips -s format png -z 256 256   src/assets/icon.png --out AppIcon.iconset/icon_256x256.png > /dev/null 2>&1
    sips -s format png -z 512 512   src/assets/icon.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null 2>&1
    sips -s format png -z 512 512   src/assets/icon.png --out AppIcon.iconset/icon_512x512.png > /dev/null 2>&1
    sips -s format png -z 1024 1024 src/assets/icon.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null 2>&1
    
    iconutil -c icns AppIcon.iconset -o "$RESOURCES_DIR/AppIcon.icns"
    rm -rf AppIcon.iconset
    rm -f test_16.png test_16.jpg
    echo "✓ AppIcon.icns generated."
else
    echo "⚠ Warning: src/assets/icon.png not found. App bundle will use default system icon."
fi

echo "🚀 Build completed successfully!"
echo "🔒 Applying local ad-hoc code signature..."
codesign --force --deep --sign - "$APP_BUNDLE"
echo "📍 App Bundle Location: $APP_BUNDLE"
echo "⭐ Launching $APP_NAME..."
open -n "$APP_BUNDLE"
