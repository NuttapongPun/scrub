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

# Version flows from the environment so the release pipeline can derive it from the git tag
# (issue #12). Falls back to dev defaults for local builds.
SHORT_VERSION="${SCRUB_VERSION:-0.1.0}"
BUILD_VERSION="${SCRUB_BUILD:-1}"

# Signing identity. Defaults to ad-hoc ("-") so local/CI builds need no secrets; a Developer ID
# step (#2) slots in by exporting SCRUB_SIGN_IDENTITY without touching the rest of this script.
SIGN_IDENTITY="${SCRUB_SIGN_IDENTITY:--}"

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
    <string>$SHORT_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <!-- Accessory app: menu-bar only, no Dock icon. -->
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 NuttapongPun. Licensed under the GNU General Public License v3.0.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Sign so the Accessibility grant sticks to a stable code identity across launches. Ad-hoc
# ("-") by default; a real Developer ID identity slots in via SCRUB_SIGN_IDENTITY (#2).
codesign --force --sign "$SIGN_IDENTITY" "$APP" >/dev/null 2>&1 || \
    echo "warning: codesign ($SIGN_IDENTITY) failed; Accessibility grant may not persist."

echo "Built $APP ($SHORT_VERSION build $BUILD_VERSION)"
