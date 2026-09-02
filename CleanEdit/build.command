#!/bin/bash
# Double-clickable build launcher for CleanEdit.
# In Finder: right-click -> Open (first time) to bypass Gatekeeper, or run in Terminal.
# Requires: Xcode Command Line Tools (clang++).
set -e

# Run from this script's own folder regardless of where it was launched.
cd "$(dirname "$0")"

APP_NAME="CleanEdit"
BUILD_DIR="build"
BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$BUNDLE/Contents"

echo "==> Cleaning previous build"
rm -rf "$BUILD_DIR"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

echo "==> Compiling sources"
clang++ -std=c++17 -fobjc-arc -ObjC++ \
    -mmacosx-version-min=11.0 \
    -Wall -Wno-unused-variable \
    src/*.mm \
    -framework Cocoa \
    -framework JavaScriptCore \
    -o "$CONTENTS/MacOS/$APP_NAME"

echo "==> Assembling app bundle"
cp Info.plist "$CONTENTS/Info.plist"
cp -R Resources/languages "$CONTENTS/Resources/"
cp -R Resources/scripts "$CONTENTS/Resources/"

echo ""
echo "Build complete: $BUNDLE"
echo "==> Launching CleanEdit"
open "$BUNDLE"
