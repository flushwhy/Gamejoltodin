#!/bin/bash
# Runs the full test suite on Linux and macOS:
#   1. Odin Unit Tests
#   2. Shared Library Build
#   3. C ABI Integration Tests
set -e

echo "============================================================"
echo "  1. Running Odin Unit Tests"
echo "============================================================"

CURL_FLAGS="-lcurl"
if [ "$(uname -s)" = "Darwin" ]; then
    if [ -d "/opt/homebrew/opt/curl/lib" ]; then
        CURL_FLAGS="-L/opt/homebrew/opt/curl/lib -lcurl"
    elif [ -d "/usr/local/opt/curl/lib" ]; then
        CURL_FLAGS="-L/usr/local/opt/curl/lib -lcurl"
    fi
fi

odin test gamejolt -extra-linker-flags:"$CURL_FLAGS"

echo ""
echo "============================================================"
echo "  2. Building Shared Library"
echo "============================================================"
./build.sh

echo ""
echo "============================================================"
echo "  3. Compiling and Running C ABI Integration Tests"
echo "============================================================"

case "$(uname -s)" in
    Darwin)
        cc -I. tests/test_c_api.c -Lbin -lgamejolt -Wl,-rpath,@loader_path/ -o bin/test_c_api
        ;;
    Linux)
        cc -I. tests/test_c_api.c -Lbin -lgamejolt -Wl,-rpath,'$ORIGIN/' -o bin/test_c_api
        ;;
    *)
        echo "Unsupported platform for run_tests.sh. On Windows, use run_tests.bat."
        exit 1
        ;;
esac

./bin/test_c_api

echo ""
echo "============================================================"
echo "  All Odin and C ABI tests passed successfully."
echo "============================================================"
