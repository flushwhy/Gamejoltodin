@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo   1. Running Odin Unit Tests
echo ============================================================

call "%~dp0ensure_curl.bat"
if errorlevel 1 exit /b 1
set "CURL_LINK_FLAGS=-extra-linker-flags:"/LIBPATH:%GAMEJOLT_CURL_LIB_DIR% libcurl.lib""

odin test gamejolt -linker:msvc %CURL_LINK_FLAGS%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Odin unit tests failed!
    exit /b %ERRORLEVEL%
)

echo.
echo ============================================================
echo   2. Building Shared Library
echo ============================================================
call build.bat
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Shared library build failed!
    exit /b %ERRORLEVEL%
)

echo.
echo ============================================================
echo   3. Compiling and Running C ABI Integration Tests
echo ============================================================

if not exist bin mkdir bin

cl /nologo /I. tests\test_c_api.c /Fe:bin\test_c_api.exe /link /LIBPATH:bin gamejolt.lib
if %ERRORLEVEL% neq 0 (
    echo [ERROR] C ABI compilation failed!
    exit /b %ERRORLEVEL%
)

bin\test_c_api.exe
if %ERRORLEVEL% neq 0 (
    echo [ERROR] C ABI test execution failed!
    exit /b %ERRORLEVEL%
)

echo.
echo ============================================================
echo   All Odin and C ABI tests passed successfully.
echo ============================================================
