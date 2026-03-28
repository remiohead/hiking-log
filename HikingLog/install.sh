#!/bin/bash
set -e

APP_NAME="Hiking"
APP_BUNDLE="/Applications/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
BUILD_DIR=".build/arm64-apple-macosx/release"

echo "Building release..."
cd "$(dirname "$0")"
swift build -c release

echo "Creating app bundle..."
mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"

# Copy SPM resource bundle next to the executable (where Bundle.module looks for it)
cp -R "${BUILD_DIR}/Hiking_Hiking.bundle" "${MACOS}/Hiking_Hiking.bundle"

# Copy app icon
cp "HikingLog/Resources/AppIcon.icns" "${RESOURCES}/AppIcon.icns"

# Create Info.plist
cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Hiking</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.hiking.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Hiking</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.healthcare-fitness</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Hiking uses your Photos library to show pictures taken on your hike days.</string>
</dict>
</plist>
PLIST

echo ""
echo "Installed to ${APP_BUNDLE}"
echo "Data is stored in iCloud Drive (~/Library/Mobile Documents/com~apple~CloudDocs/Hiking/) or ~/Library/Application Support/Hiking/"
echo ""
echo "To launch: open /Applications/Hiking.app"
