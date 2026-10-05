@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo   1. Running Odin Unit Tests
echo ============================================================

:: Default fallback linker flag
set "CURL_LINK_FLAGS=-extra-linker-flags:libcurl.lib"

:: Check common libcurl locations on Windows runners and local dev machines
if exist "C:\ProgramData\chocolatey\lib\curl\tools\curl-*\lib\libcurl.lib" (
    for /d %%D in ("C:\ProgramData\chocolatey\lib\curl\tools\curl-*") do (
        set "CURL_LINK_FLAGS=-extra-linker-flags:"/LIBPATH:%%D\lib libcurl.lib""
    )
) else if exist "deps\curl\lib\libcurl.lib" (
    set "CURL_LINK_FLAGS=-extra-linker-flags:"/LIBPATH:deps\curl\lib libcurl.lib""
) else if exist "vendor\curl\lib\libcurl.lib" (
    set "CURL_LINK_FLAGS=-extra-linker-flags:"/LIBPATH:vendor\curl\lib libcurl.lib""
) else if defined VCPKG_INSTALLATION_ROOT (
    if exist "%VCPKG_INSTALLATION_ROOT%\x64-windows\lib\libcurl.lib" (
        set "CURL_LINK_FLAGS=-extra-linker-flags:"/LIBPATH:%VCPKG_INSTALLATION_ROOT%\x64-windows\lib libcurl.lib""
    )
)

odin test gamejolt %CURL_LINK_FLAGS%
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