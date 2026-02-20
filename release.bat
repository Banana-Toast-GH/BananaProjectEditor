@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: release.bat ^<version^> ^"Release notes^"
    echo Example: release.bat v0.3.0 "Added sounds"
    pause & exit /b 1
)

set VERSION=%~1
set NOTES=%~2
if "%NOTES%"=="" set NOTES=Banana Project Editor %VERSION%

set GIT_DIR=C:\Users\banan\Downloads\BPE
set BPE_DIR=C:\Users\banan\Downloads\BananaProjectEditor\BananaProjectEditor

:: Zip goes to TEMP so it never pollutes the git folder
set ZIP=%TEMP%\BananaProjectEditor.zip

echo.
echo [BPE] Version:    %VERSION%
echo [BPE] Source:     %BPE_DIR%
echo [BPE] Git repo:   %GIT_DIR%
echo.

:: 1 - Build
echo [1/5] Building...
cd /d "%BPE_DIR%"
call build.bat
if errorlevel 1 ( echo Build failed! & pause & exit /b 1 )

:: 2 - version.txt
echo [2/5] Updating version.txt...
echo %VERSION%> "%GIT_DIR%\version.txt"

:: 3 - Zip to TEMP
echo [3/5] Zipping to temp...
if exist "%ZIP%" del /f /q "%ZIP%"
powershell -Command "Compress-Archive -Path '%BPE_DIR%\*' -DestinationPath '%ZIP%' -Force"
if not exist "%ZIP%" ( echo Zip failed! & pause & exit /b 1 )
echo Zip created at %ZIP%

:: 4 - Git push from GIT_DIR
echo [4/5] Pushing to GitHub...
cd /d "%GIT_DIR%"
git add -A
git commit -m "Release %VERSION%: %NOTES%"
git push origin main
if errorlevel 1 ( echo Git push failed! & pause & exit /b 1 )

:: 5 - GitHub Release
echo [5/5] Creating GitHub Release...
gh release delete %VERSION% --yes --repo Banana-Toast-GH/BananaProjectEditor 2>nul
gh release create %VERSION% "%ZIP%" --title "Banana Project Editor %VERSION%" --notes "%NOTES%" --repo Banana-Toast-GH/BananaProjectEditor
if errorlevel 1 ( echo GitHub release failed! & pause & exit /b 1 )

:: Cleanup
del /f /q "%ZIP%" 2>nul

echo.
echo =====================================================
echo  Done! Install with:
echo  irm https://raw.githubusercontent.com/Banana-Toast-GH/BananaProjectEditor/main/install-web.ps1 ^| iex
echo =====================================================
pause
