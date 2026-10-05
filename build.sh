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
        
        ARCH=$(uname -m)
        EXTRA_FLAGS="-no-entry-point"

        if [ "$ARCH" = "arm64" ]; then
            echo "Targeting Apple Silicon (arm64)..."
            EXTRA_FLAGS="$EXTRA_FLAGS -target:darwin_arm64"
            if [ -d "/opt/homebrew/opt/curl/lib" ]; then
                CURL_FLAGS="-L/opt/homebrew/opt/curl/lib -lcurl"
            else
                CURL_FLAGS="-lcurl"
            fi
        else
            echo "Targeting Intel (x86_64)..."
            EXTRA_FLAGS="$EXTRA_FLAGS -target:darwin_amd64"
            if [ -d "/usr/local/opt/curl/lib" ]; then
                CURL_FLAGS="-L/usr/local/opt/curl/lib -lcurl"
            else
                CURL_FLAGS="-lcurl"
            fi
        fi

        odin build "$PACKAGE" \
            -build-mode:shared \
            -out:"$OUT_DIR/libgamejolt.dylib" \
            $EXTRA_FLAGS \
            -extra-linker-flags:"$CURL_FLAGS" \
            -o:speed
        echo "Output: $OUT_DIR/libgamejolt.dylib"
        ;;
    Linux)
        echo "Building for Linux..."
        odin build "$PACKAGE" \
            -build-mode:shared \
            -out:"$OUT_DIR/libgamejolt.so" \
            -no-entry-point \
            -extra-linker-flags:"-lcurl" \
            -o:speed
        echo "Output: $OUT_DIR/libgamejolt.so"
        ;;
    *)
        echo "Unknown or unsupported platform for build.sh. On Windows, use build.bat."
        exit 1
        ;;
esac