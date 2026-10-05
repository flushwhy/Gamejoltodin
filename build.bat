@echo off
setlocal enabledelayedexpansion

:: Builds the GameJolt Odin library as a shared library (.dll)
:: Requires: Odin compiler, libcurl

set PACKAGE=.\gamejolt
set OUT_DIR=.\bin

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

echo Building for Windows...

:: Default linker flag for libcurl
set "CURL_LINK_FLAGS=-extra-linker-flags:libcurl.lib"

:: Check common libcurl.lib search locations on Windows
if exist "deps\curl\lib\libcurl.lib" (
    set "CURL_LINK_FLAGS=-extra-linker-flags:"/LIBPATH:deps\curl\lib libcurl.lib""
) else if exist "vendor\curl\lib\libcurl.lib" (
    set "CURL_LINK_FLAGS=-extra-linker-flags:"/LIBPATH:vendor\curl\lib libcurl.lib""
) else if exist "C:\odin\vendor\curl\lib\libcurl.lib" (
    set "CURL_LINK_FLAGS=-extra-linker-flags:"/LIBPATH:C:\odin\vendor\curl\lib libcurl.lib""
) else if defined VCPKG_INSTALLATION_ROOT (
    if exist "%VCPKG_INSTALLATION_ROOT%\x64-windows\lib\libcurl.lib" (
        set "CURL_LINK_FLAGS=-extra-linker-flags:"/LIBPATH:%VCPKG_INSTALLATION_ROOT%\x64-windows\lib libcurl.lib""
    )
)

odin build %PACKAGE% ^
    -build-mode:shared ^
    -no-entry-point ^
    -out:%OUT_DIR%\gamejolt.dll ^
    %CURL_LINK_FLAGS% ^
    -o:speed

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Shared library build failed!
    exit /b %ERRORLEVEL%
)

echo Output: %OUT_DIR%\gamejolt.dll