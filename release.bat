@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: release.bat ^<version^> ^"Release notes^"
    pause & exit /b 1
)

set VERSION=%~1
set NOTES=%~2
if "%NOTES%"=="" set NOTES=Banana Project Editor %VERSION%

set GIT_DIR=C:\Users\banan\Downloads\BPE
set BPE_DIR=C:\Users\banan\Downloads\BananaProjectEditor\BananaProjectEditor

echo.
echo [BPE Release] Version: %VERSION%
echo [BPE Release] Notes:   %NOTES%
echo.

:: Step 1 - Build
echo [1/5] Building JAR...
cd /d "%BPE_DIR%"
call build.bat
if errorlevel 1 ( echo Build failed! & pause & exit /b 1 )

:: Step 2 - version.txt
echo [2/5] Updating version.txt...
echo %VERSION%> "%GIT_DIR%\version.txt"

:: Step 3 - Zip
echo [3/5] Zipping...
if exist "%GIT_DIR%\BananaProjectEditor.zip" del /f /q "%GIT_DIR%\BananaProjectEditor.zip"
powershell -Command "Compress-Archive -Path '%BPE_DIR%\*' -DestinationPath '%GIT_DIR%\BananaProjectEditor.zip' -Force"
if not exist "%GIT_DIR%\BananaProjectEditor.zip" ( echo Zip failed! & pause & exit /b 1 )
echo Zip created.

:: Step 4 - Git (cd INTO the git folder first)
echo [4/5] Committing...
cd /d "%GIT_DIR%"
echo Current dir: %CD%
git add -A
git commit -m "Release %VERSION%: %NOTES%"
git push origin main
if errorlevel 1 ( echo Git push failed! & pause & exit /b 1 )

:: Step 5 - GitHub Release
echo [5/5] Creating GitHub Release...
gh release create %VERSION% "%GIT_DIR%\BananaProjectEditor.zip" --title "Banana Project Editor %VERSION%" --notes "%NOTES%" --repo Banana-Toast-GH/BananaProjectEditor
if errorlevel 1 ( echo GitHub release failed! Run 'gh auth login' first. & pause & exit /b 1 )

echo.
echo =====================================================
echo  Done! Install with:
echo  irm https://raw.githubusercontent.com/Banana-Toast-GH/BananaProjectEditor/main/install-web.ps1 ^| iex
echo =====================================================
pause
