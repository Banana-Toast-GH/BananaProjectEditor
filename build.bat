@echo off
chcp 65001 >nul

:: Set working directory to this script's folder
pushd "%~dp0"

echo [BPE] Building Banana Project Editor...
echo [BPE] Working directory: %CD%

set OUT_DIR=out
set JAR_NAME=BananaProjectEditor.jar
set MAIN_CLASS=com.bpe.editor.Main

:: Clean output dir
if exist "%OUT_DIR%" rmdir /s /q "%OUT_DIR%"
mkdir "%OUT_DIR%"

:: Delete old jar if it exists (overwrite)
if exist "%JAR_NAME%" (
    echo [BPE] Removing old %JAR_NAME%...
    del /f /q "%JAR_NAME%"
)

:: Find all .java files
echo [BPE] Finding source files...
del /f /q sources.txt 2>nul
for /r "src" %%f in (*.java) do (
    echo %%f>> sources.txt
)

:: Verify sources found
if not exist sources.txt goto NO_SOURCES
for %%A in (sources.txt) do if %%~zA==0 goto NO_SOURCES
goto COMPILE

:NO_SOURCES
echo [ERROR] No .java files found in src folder!
echo [BPE] Make sure you extracted the full zip contents, not just build.bat
del /f /q sources.txt 2>nul
popd
pause
exit /b 1

:COMPILE
echo [BPE] Compiling...
javac -encoding UTF-8 -d "%OUT_DIR%" @sources.txt
if errorlevel 1 (
    echo [ERROR] Compilation failed!
    del /f /q sources.txt
    popd
    pause
    exit /b 1
)
echo [OK] Compiled successfully

:: Write manifest
(echo Main-Class: %MAIN_CLASS%) > manifest.txt

:: Package jar
echo [BPE] Packaging...
jar cfm "%JAR_NAME%" manifest.txt -C "%OUT_DIR%" .
if errorlevel 1 (
    echo [ERROR] Packaging failed!
    del /f /q sources.txt manifest.txt
    popd
    pause
    exit /b 1
)
echo [OK] Packaged: %JAR_NAME%

:: Cleanup temp files
del /f /q sources.txt manifest.txt
rmdir /s /q "%OUT_DIR%"

echo.
echo ================================
echo  [BPE] Build complete!
echo  Run: java -jar %JAR_NAME%
echo ================================
popd
pause
