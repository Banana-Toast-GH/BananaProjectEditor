@echo off
:: BPE Release Script
:: Requires: git, gh (GitHub CLI) — install gh from https://cli.github.com
:: Usage: release.bat v0.3.0 "What changed in this release"

setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: release.bat ^<version^> ^"Release notes^"
    echo Example: release.bat v0.3.0 "Added block editor and code assist"
    pause & exit /b 1
)

set VERSION=%~1
set NOTES=%~2
if "%NOTES%"=="" set NOTES=Banana Project Editor %VERSION%

echo.
echo [BPE Release] Version: %VERSION%
echo [BPE Release] Notes:   %NOTES%
echo.

:: Step 1 — Build the JAR
echo [1/5] Building JAR...
call build.bat
if errorlevel 1 ( echo Build failed! & pause & exit /b 1 )

:: Step 2 — Update version.txt
echo [2/5] Updating version.txt...
echo %VERSION%> version.txt
echo Updated version.txt to %VERSION%

:: Step 3 — Zip the project
echo [3/5] Creating BananaProjectEditor.zip...
if exist BananaProjectEditor.zip del /f /q BananaProjectEditor.zip
powershell -Command "Compress-Archive -Path '.\*' -DestinationPath '.\BananaProjectEditor.zip' -Force"
if not exist BananaProjectEditor.zip ( echo Zip failed! & pause & exit /b 1 )
echo Zip created.

:: Step 4 — Commit and push
echo [4/5] Committing to git...
git add -A
git commit -m "Release %VERSION%: %NOTES%"
git push origin main
if errorlevel 1 ( echo Git push failed! & pause & exit /b 1 )

:: Step 5 — Create GitHub Release with gh CLI
echo [5/5] Creating GitHub Release %VERSION%...
gh release create %VERSION% BananaProjectEditor.zip ^
    --title "Banana Project Editor %VERSION%" ^
    --notes "%NOTES%" ^
    --repo Banana-Toast-GH/BananaProjectEditor
if errorlevel 1 ( echo GitHub release failed! Check 'gh auth status'. & pause & exit /b 1 )

echo.
echo =====================================================
echo  Release %VERSION% published successfully!
echo  Users can now install with:
echo.
echo  irm https://raw.githubusercontent.com/Banana-Toast-GH/BananaProjectEditor/main/install-web.ps1 ^| iex
echo =====================================================
echo.
pause
