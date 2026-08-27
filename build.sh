#!/bin/bash
# Builds the GameJolt Odin library as a shared library (.so / .dylib)
# Requires: Odin compiler, libcurl
 
set -e
 
PACKAGE="./gamejolt"
OUT_DIR="./bin"
 
mkdir -p "$OUT_DIR"
 
case "$(uname -s)" in
    Darwin)
        echo "Building for macOS..."
        odin build "$PACKAGE" \
            -build-mode:shared \
            -out:"$OUT_DIR/libgamejolt.dylib" \
            -extra-linker-flags:"-lcurl" \
            -o:speed
        echo "Output: $OUT_DIR/libgamejolt.dylib"
        ;;
    Linux)
        echo "Building for Linux..."
        odin build "$PACKAGE" \
            -build-mode:shared \
            -out:"$OUT_DIR/libgamejolt.so" \
            -extra-linker-flags:"-lcurl" \
            -o:speed
        echo "Output: $OUT_DIR/libgamejolt.so"
        ;;
    *)
        echo "Use build.bat on Windows"
        exit 1
        ;;
esac
 