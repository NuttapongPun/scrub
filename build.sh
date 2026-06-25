#!/bin/bash
# Builds Scrub and wraps the binary into a runnable Scrub.app bundle.
#
# Scrub needs Accessibility permission and so cannot be sandboxed or App Store distributed
# (see AGENTS.md). The bundle is an accessory-policy app: a menu-bar item, no Dock icon.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="Scrub.app"
BUNDLE_ID="com.nuttapongpun.scrub"

echo "Building Scrub ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/Scrub"

echo "Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN_PATH" "$APP/Contents/MacOS/Scrub"
cp "Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Scrub</string>
    <key>CFBundleDisplayName</key>
    <string>Scrub</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>Scrub</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <!-- Accessory app: menu-bar only, no Dock icon. -->
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so the Accessibility grant sticks to a stable code identity across launches.
codesign --force --sign - "$APP" >/dev/null 2>&1 || \
    echo "warning: ad-hoc codesign failed; Accessibility grant may not persist."

echo "Built $APP"
