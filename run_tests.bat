@echo off

echo ============================================================
echo   1. Running Odin Unit Tests
echo ============================================================
odin test gamejolt -extra-linker-flags:"C:\odin\vendor\curl\lib\libcurl.lib"
if %errorlevel% neq 0 (
    echo [ERROR] Odin unit tests failed!
    exit /b %errorlevel%
)

echo.
echo ============================================================
echo   2. Building Shared Library (gamejolt.dll)
echo ============================================================
call build.bat
if %errorlevel% neq 0 (
    echo [ERROR] Build failed!
    exit /b %errorlevel%
)

echo.
echo ============================================================
echo   3. Compiling and Running C ABI Integration Tests
echo ============================================================
gcc -I. tests/test_c_api.c bin/gamejolt.lib -o bin/test_c_api.exe
if %errorlevel% neq 0 (
    echo [ERROR] Failed to compile C integration tests!
    exit /b %errorlevel%
)

.\bin\test_c_api.exe
if %errorlevel% neq 0 (
    echo [ERROR] C integration tests failed!
    exit /b %errorlevel%
)

echo.
echo ============================================================
echo   All Odin and C ABI tests passed successfully.
echo ============================================================
exit /b 0

