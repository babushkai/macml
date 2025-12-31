#!/bin/bash
set -e

APP_NAME="Performant3"
BUNDLE_ID="com.performant3.app"

# Get version from environment variable, git tag, or default
if [ -n "$VERSION" ]; then
    echo "Using version from environment: $VERSION"
elif git describe --tags --exact-match 2>/dev/null; then
    VERSION=$(git describe --tags --exact-match 2>/dev/null | sed 's/^v//')
    echo "Using version from git tag: $VERSION"
else
    VERSION="1.0.0-dev"
    echo "Using default development version: $VERSION"
fi

echo "Building $APP_NAME with xcodebuild (required for Metal shaders)..."

# Build with xcodebuild (required for Metal shader compilation)
xcodebuild -scheme Performant3 -destination 'platform=macOS' -configuration Release build

# Find the build products directory
DERIVED_DATA=$(xcodebuild -scheme Performant3 -showBuildSettings 2>/dev/null | grep -m 1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')

if [ -z "$DERIVED_DATA" ]; then
    # Fallback to find it
    DERIVED_DATA=$(find ~/Library/Developer/Xcode/DerivedData -name "peformant3-*" -type d 2>/dev/null | head -1)/Build/Products/Release
fi

echo "Build products at: $DERIVED_DATA"

# Create app bundle structure
APP_DIR="$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Frameworks"

# Copy executable
cp "$DERIVED_DATA/Performant3" "$APP_DIR/Contents/MacOS/"

# Copy Info.plist and update version
cp Info.plist "$APP_DIR/Contents/"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_DIR/Contents/Info.plist"

# Copy Metal library bundle (critical for MLX)
if [ -d "$DERIVED_DATA/mlx-swift_Cmlx.bundle" ]; then
    cp -R "$DERIVED_DATA/mlx-swift_Cmlx.bundle" "$APP_DIR/Contents/Resources/"
    echo "Copied MLX Metal library bundle"
fi

# Copy other bundles
for bundle in "$DERIVED_DATA"/*.bundle; do
    if [ -d "$bundle" ]; then
        cp -R "$bundle" "$APP_DIR/Contents/Resources/"
        echo "Copied $(basename "$bundle")"
    fi
done

# Copy Python training scripts
if [ -d "Resources/Scripts" ]; then
    mkdir -p "$APP_DIR/Contents/Resources/Scripts"
    cp -R Resources/Scripts/* "$APP_DIR/Contents/Resources/Scripts/"
    echo "Copied Python training scripts"
fi

# Copy app icon
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
    echo "Copied app icon"
fi

# Copy frameworks if any
for framework in "$DERIVED_DATA/PackageFrameworks"/*.framework; do
    if [ -d "$framework" ]; then
        cp -R "$framework" "$APP_DIR/Contents/Frameworks/"
        echo "Copied $(basename "$framework")"
    fi
done

# Create PkgInfo
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

echo "Created $APP_DIR"

# Sign the app
if [ -n "$SIGNING_IDENTITY" ]; then
    echo "Signing with identity: $SIGNING_IDENTITY"
    codesign --force --deep --options runtime --sign "$SIGNING_IDENTITY" "$APP_DIR"
else
    echo "Using ad-hoc signing (set SIGNING_IDENTITY for Developer ID signing)"
    codesign --force --deep --sign - "$APP_DIR"
fi

# Create DMG
echo "Creating DMG..."
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
rm -f "$DMG_NAME"

# Create temporary directory for DMG contents
DMG_DIR="dmg_contents"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$APP_DIR" "$DMG_DIR/"

# Create symlink to Applications
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_NAME"

# Cleanup
rm -rf "$DMG_DIR"

echo ""
echo "Build complete!"
echo "  App bundle: $APP_DIR"
echo "  DMG file:   $DMG_NAME"
echo ""
echo "To run: open $APP_DIR"
echo "To install: Open $DMG_NAME and drag $APP_NAME to Applications"
