@echo off
title Build BPE
echo ================================
echo  Banana Project Editor Builder
echo ================================
echo.

set ZIP=%~dp0BananaProjectEditor.zip
set DEST=C:\BPE

if not exist "%ZIP%" (
    echo [ERROR] BananaProjectEditor.zip not found next to this file!
    pause & exit /b 1
)

echo [1/3] Extracting to C:\BPE...
taskkill /f /im java.exe >nul 2>&1
taskkill /f /im javaw.exe >nul 2>&1
if exist "%DEST%" rmdir /s /q "%DEST%"
powershell -Command "Expand-Archive -Path '%ZIP%' -DestinationPath 'C:\BPE' -Force"
echo Done.

echo [2/3] Building...
pushd "%DEST%\BananaProjectEditor"
call build.bat
set ERR=%ERRORLEVEL%
popd
if %ERR% neq 0 ( echo [ERROR] Build failed! & pause & exit /b 1 )

echo.
echo ================================
echo  Done! Run BPE with:
echo  java -jar C:\BPE\BananaProjectEditor\BananaProjectEditor.jar
echo ================================
pause
