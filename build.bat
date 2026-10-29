@echo off
setlocal enabledelayedexpansion

:: Builds the GameJolt Odin library as a shared library (.dll)
:: Requires: Odin compiler, MSVC build tools, and libcurl.

set PACKAGE=.\gamejolt
set OUT_DIR=.\bin

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

echo Building for Windows...

:: Use MSVC link.exe and the CRT libraries needed by the generated objects.
call "%~dp0ensure_curl.bat"
if errorlevel 1 exit /b 1
set "CURL_LINK_FLAGS=-extra-linker-flags:"/DEFAULTLIB:libcmt /DEFAULTLIB:libucrt /DEFAULTLIB:libvcruntime /LIBPATH:%GAMEJOLT_CURL_LIB_DIR% libcurl.lib""

odin build %PACKAGE% ^
    -build-mode:shared ^
    -no-entry-point ^
    -use-single-module ^
    -linker:msvc ^
    -out:%OUT_DIR%\gamejolt.dll ^
    %CURL_LINK_FLAGS% ^
    -o:speed

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Shared library build failed!
    exit /b %ERRORLEVEL%
)

echo Output: %OUT_DIR%\gamejolt.dll
