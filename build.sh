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
        CURL_FLAGS="-lcurl"
        if [ -d "/opt/homebrew/opt/curl/lib" ]; then
            CURL_FLAGS="-L/opt/homebrew/opt/curl/lib -lcurl"
        elif [ -d "/usr/local/opt/curl/lib" ]; then
            CURL_FLAGS="-L/usr/local/opt/curl/lib -lcurl"
        fi
        odin build "$PACKAGE" \
            -build-mode:shared \
            -out:"$OUT_DIR/libgamejolt.dylib" \
            -extra-linker-flags:"$CURL_FLAGS" \
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
        echo "Unknown or unsupported platform for build.sh. On Windows, use build.bat."
        exit 1
        ;;
esac