@echo off
:: BPE Release Script
:: Requires: git, gh (GitHub CLI) — install gh from https://cli.github.com
:: Usage: release.bat <version> "Release notes"

setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: release.bat ^<version^> ^"Release notes^"
    echo Example: release.bat v0.3.0 "Added block editor and code assist"
    pause & exit /b 1
)

set VERSION=%~1
set NOTES=%~2
if "%NOTES%"=="" set NOTES=Banana Project Editor %VERSION%

:: Auto-find BPE project folder
set BPE_DIR=
for %%d in (
    "%USERPROFILE%\Downloads\BananaProjectEditor\BananaProjectEditor"
    "%USERPROFILE%\Desktop\BananaProjectEditor\BananaProjectEditor"
    "%USERPROFILE%\Documents\BananaProjectEditor\BananaProjectEditor"
    "C:\BananaProjectEditor"
) do (
    if exist "%%~d\build.bat" (
        if not defined BPE_DIR set BPE_DIR=%%~d
    )
)

if not defined BPE_DIR (
    echo Could not find BPE project folder automatically.
    set /p BPE_DIR="Enter full path to BPE folder (contains build.bat): "
)

if not exist "%BPE_DIR%\build.bat" (
    echo ERROR: build.bat not found in %BPE_DIR%
    pause & exit /b 1
)

echo.
echo [BPE Release] Version:    %VERSION%
echo [BPE Release] Notes:      %NOTES%
echo [BPE Release] Project at: %BPE_DIR%
echo.

cd /d "%BPE_DIR%"

:: Step 1 - Build the JAR
echo [1/5] Building JAR...
call build.bat
if errorlevel 1 ( echo Build failed! & pause & exit /b 1 )

:: Step 2 - Update version.txt
echo [2/5] Updating version.txt...
echo %VERSION%> version.txt
echo Updated version.txt to %VERSION%

:: Step 3 - Zip the project
echo [3/5] Creating BananaProjectEditor.zip...
if exist BananaProjectEditor.zip del /f /q BananaProjectEditor.zip
powershell -Command "Compress-Archive -Path '.\*' -DestinationPath '.\BananaProjectEditor.zip' -Force"
if not exist BananaProjectEditor.zip ( echo Zip failed! & pause & exit /b 1 )
echo Zip created.

:: Step 4 - Commit and push
echo [4/5] Committing to git...
git add -A
git commit -m "Release %VERSION%: %NOTES%"
git push origin main
if errorlevel 1 ( echo Git push failed! Make sure git is set up in this folder. & pause & exit /b 1 )

:: Step 5 - Create GitHub Release
echo [5/5] Creating GitHub Release %VERSION%...
gh release create %VERSION% BananaProjectEditor.zip ^
    --title "Banana Project Editor %VERSION%" ^
    --notes "%NOTES%" ^
    --repo Banana-Toast-GH/BananaProjectEditor
if errorlevel 1 ( echo GitHub release failed! Run 'gh auth login' first. & pause & exit /b 1 )

echo.
echo =====================================================
echo  Release %VERSION% published!
echo.
echo  Install command for users:
echo  irm https://raw.githubusercontent.com/Banana-Toast-GH/BananaProjectEditor/main/install-web.ps1 ^| iex
echo =====================================================
echo.
pause
