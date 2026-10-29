@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem Resolve libcurl.lib, installing the x64 vcpkg package if necessary.

set "CURL_ROOT=%~dp0"
set "CURL_LIB_DIR="

if defined GAMEJOLT_CURL_LIB_DIR if exist "%GAMEJOLT_CURL_LIB_DIR%\libcurl.lib" set "CURL_LIB_DIR=%GAMEJOLT_CURL_LIB_DIR%"
if not defined CURL_LIB_DIR if exist "%CURL_ROOT%odin\vendor\curl\lib\libcurl.lib" set "CURL_LIB_DIR=%CURL_ROOT%odin\vendor\curl\lib"
if not defined CURL_LIB_DIR if exist "%CURL_ROOT%deps\curl\lib\libcurl.lib" set "CURL_LIB_DIR=%CURL_ROOT%deps\curl\lib"
if not defined CURL_LIB_DIR if exist "%CURL_ROOT%vendor\curl\lib\libcurl.lib" set "CURL_LIB_DIR=%CURL_ROOT%vendor\curl\lib"
if not defined CURL_LIB_DIR if exist "C:\odin\vendor\curl\lib\libcurl.lib" set "CURL_LIB_DIR=C:\odin\vendor\curl\lib"
if not defined CURL_LIB_DIR if defined VCPKG_INSTALLATION_ROOT if exist "%VCPKG_INSTALLATION_ROOT%\installed\x64-windows\lib\libcurl.lib" set "CURL_LIB_DIR=%VCPKG_INSTALLATION_ROOT%\installed\x64-windows\lib"
if not defined CURL_LIB_DIR if exist "%LOCALAPPDATA%\vcpkg\installed\x64-windows\lib\libcurl.lib" set "CURL_LIB_DIR=%LOCALAPPDATA%\vcpkg\installed\x64-windows\lib"

if not defined CURL_LIB_DIR (
    echo [curl] libcurl.lib not found; installing curl:x64-windows with vcpkg...
    set "VCPKG_ROOT=%VCPKG_INSTALLATION_ROOT%"
    if not defined VCPKG_ROOT set "VCPKG_ROOT=%LOCALAPPDATA%\vcpkg"
    if not exist "!VCPKG_ROOT!\vcpkg.exe" (
        if exist "!VCPKG_ROOT!" if not exist "!VCPKG_ROOT!\.git" set "VCPKG_ROOT=%LOCALAPPDATA%\vcpkg-bootstrap"
        if not exist "!VCPKG_ROOT!\vcpkg.exe" (
            if not exist "!VCPKG_ROOT!\.git" (
                git clone https://github.com/microsoft/vcpkg.git "!VCPKG_ROOT!"
                if errorlevel 1 (
                    echo [ERROR] Could not download vcpkg. Install Git or set VCPKG_INSTALLATION_ROOT.
                    endlocal
                    exit /b 1
                )
            )
            call "!VCPKG_ROOT!\bootstrap-vcpkg.bat" -disableMetrics
            if errorlevel 1 (
                endlocal
                exit /b 1
            )
        )
    )
    call "!VCPKG_ROOT!\vcpkg.exe" install curl:x64-windows
    if errorlevel 1 (
        endlocal
        exit /b 1
    )
    set "CURL_LIB_DIR=!VCPKG_ROOT!\installed\x64-windows\lib"
)

if not exist "!CURL_LIB_DIR!\libcurl.lib" (
    echo [ERROR] libcurl.lib was not found after dependency setup.
    echo Checked: "!CURL_LIB_DIR!\libcurl.lib"
    endlocal & exit /b 1
)

set "CURL_BIN_DIR="
if exist "!CURL_LIB_DIR!\..\bin" set "CURL_BIN_DIR=!CURL_LIB_DIR!\..\bin"
echo [curl] Using libcurl.lib: "!CURL_LIB_DIR!\libcurl.lib"
endlocal & set "GAMEJOLT_CURL_LIB_DIR=%CURL_LIB_DIR%" & set "LIB=%CURL_LIB_DIR%;%LIB%" & set "PATH=%CURL_BIN_DIR%;%PATH%"
exit /b 0
