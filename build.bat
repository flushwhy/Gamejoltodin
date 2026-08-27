
@echo off
:: Builds the GameJolt Odin library as a shared library (.dll)
:: Requires: Odin compiler, libcurl
 
set PACKAGE=.\gamejolt
set OUT_DIR=.\bin
 
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
 
echo Building for Windows...
odin build %PACKAGE% ^
    -build-mode:shared ^
    -out:%OUT_DIR%\gamejolt.dll ^
    -extra-linker-flags:"C:\odin\vendor\curl\lib\libcurl.lib" ^
    -o:speed
 
echo Output: %OUT_DIR%\gamejolt.dll
 