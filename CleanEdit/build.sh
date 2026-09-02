#!/bin/bash
# Build script for CleanEdit (native macOS app).
# Requires: Xcode Command Line Tools (clang++). Run on macOS.
set -e

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
echo "Run it with:  open $BUNDLE"
echo "Or directly:  ./$CONTENTS/MacOS/$APP_NAME"
