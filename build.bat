@echo off
setlocal enabledelayedexpansion

:: Builds the GameJolt Odin library as a shared library (.dll)
:: Requires: Odin compiler, MSVC build tools, and libcurl.

set PACKAGE=.\gamejolt
set OUT_DIR=.\bin

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

echo Building for Windows...

:: vendor:curl disables the dynamic MSVC CRT default library. Explicitly link
:: the static CRT so shared-library builds resolve memcpy/memmove/memset.
set "CURL_LINK_FLAGS=-extra-linker-flags:""/DEFAULTLIB:libcmt libcurl.lib"""

if defined GAMEJOLT_CURL_LIB_DIR (
    if exist "%GAMEJOLT_CURL_LIB_DIR%\libcurl.lib" (
        set "CURL_LINK_FLAGS=-extra-linker-flags:""/DEFAULTLIB:libcmt /LIBPATH:%GAMEJOLT_CURL_LIB_DIR% libcurl.lib"""
    )
) else if exist "odin\vendor\curl\lib\libcurl.lib" (
    set "CURL_LINK_FLAGS=-extra-linker-flags:""/DEFAULTLIB:libcmt /LIBPATH:odin\vendor\curl\lib libcurl.lib"""
) else if exist "deps\curl\lib\libcurl.lib" (
    set "CURL_LINK_FLAGS=-extra-linker-flags:""/DEFAULTLIB:libcmt /LIBPATH:deps\curl\lib libcurl.lib"""
) else if exist "vendor\curl\lib\libcurl.lib" (
    set "CURL_LINK_FLAGS=-extra-linker-flags:""/DEFAULTLIB:libcmt /LIBPATH:vendor\curl\lib libcurl.lib"""
) else if exist "C:\odin\vendor\curl\lib\libcurl.lib" (
    set "CURL_LINK_FLAGS=-extra-linker-flags:""/DEFAULTLIB:libcmt /LIBPATH:C:\odin\vendor\curl\lib libcurl.lib"""
) else if defined VCPKG_INSTALLATION_ROOT (
    if exist "%VCPKG_INSTALLATION_ROOT%\x64-windows\lib\libcurl.lib" (
        set "CURL_LINK_FLAGS=-extra-linker-flags:""/DEFAULTLIB:libcmt /LIBPATH:%VCPKG_INSTALLATION_ROOT%\x64-windows\lib libcurl.lib"""
    )
)

odin build %PACKAGE% ^
    -build-mode:shared ^
    -no-entry-point ^
    -use-single-module ^
    -out:%OUT_DIR%\gamejolt.dll ^
    %CURL_LINK_FLAGS% ^
    -o:speed

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Shared library build failed!
    exit /b %ERRORLEVEL%
)

echo Output: %OUT_DIR%\gamejolt.dll
