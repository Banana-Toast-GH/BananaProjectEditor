#Requires -Version 5.1
<#
.SYNOPSIS
    Banana Project Editor Installer v0.2.5
#>

$BPE_VERSION    = "v0.2.5"
$BPE_REPO       = "Banana-Toast-GH/BananaProjectEditor"
$BPE_ZIP_URL    = "https://github.com/$BPE_REPO/releases/download/$BPE_VERSION/BananaProjectEditor.zip"
$DEFAULT_INSTALL = "$env:LOCALAPPDATA\BananaProjectEditor"

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  Banana Project Editor Installer" -ForegroundColor Yellow
    Write-Host "  Version $BPE_VERSION" -ForegroundColor DarkGray
    Write-Host "  ─────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Step($n, $total, $msg) {
    Write-Host "  [$n/$total] $msg" -ForegroundColor Cyan
}
function Write-OK($msg)   { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  !!  $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  XX  $msg" -ForegroundColor Red }

function Ensure-Java {
    Write-Step 1 5 "Checking Java..."
    $java = Get-Command java -ErrorAction SilentlyContinue
    if ($java) {
        Write-OK "Java found."
        return $true
    }
    Write-Warn "Java not found. Downloading OpenJDK 21..."
    $jdkUrl = "https://aka.ms/download-jdk/microsoft-jdk-21-windows-x64.msi"
    $jdkMsi = "$env:TEMP\openjdk21.msi"
    try {
        (New-Object System.Net.WebClient).DownloadFile($jdkUrl, $jdkMsi)
        Start-Process msiexec.exe -ArgumentList "/i `"$jdkMsi`" /quiet /norestart" -Wait
        Remove-Item $jdkMsi -Force -ErrorAction SilentlyContinue
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("PATH","User")
        Write-OK "OpenJDK 21 installed."
        return $true
    } catch {
        Write-Err "Failed to install Java: $_"
        Write-Host "    Please install Java from https://adoptium.net then re-run."
        return $false
    }
}

function Download-BPE($installDir) {
    Write-Step 2 5 "Downloading BPE $BPE_VERSION..."
    $zipPath = "$env:TEMP\BananaProjectEditor.zip"
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent","BPE-Installer/$BPE_VERSION")
        $wc.DownloadFile($BPE_ZIP_URL, $zipPath)
        Write-OK "Downloaded."
        return $zipPath
    } catch {
        Write-Err "Download failed: $_"
        return $null
    }
}

function Install-Files($zipPath, $installDir) {
    Write-Step 3 5 "Installing to $installDir..."
    if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $installDir)
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    # Move inner folder up if needed
    $inner = Get-ChildItem $installDir -Directory | Select-Object -First 1
    if ($inner -and (Test-Path "$($inner.FullName)\build.bat")) {
        Get-ChildItem $inner.FullName | Move-Item -Destination $installDir -Force
        Remove-Item $inner.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Build
    $buildBat = Join-Path $installDir "build.bat"
    if (Test-Path $buildBat) {
        Write-Host "    Building..." -ForegroundColor DarkGray
        Start-Process cmd.exe -ArgumentList "/c `"$buildBat`"" -WorkingDirectory $installDir -Wait -NoNewWindow
    }
    Write-OK "Installed."
    return $true
}

function Create-Shortcuts($installDir) {
    Write-Step 4 5 "Creating shortcuts..."
    $jarPath = Join-Path $installDir "BananaProjectEditor.jar"
    $wsh = New-Object -ComObject WScript.Shell

    # Desktop
    $lnk = $wsh.CreateShortcut("$([System.Environment]::GetFolderPath('Desktop'))\Banana Project Editor.lnk")
    $lnk.TargetPath = "javaw.exe"
    $lnk.Arguments  = "-jar `"$jarPath`""
    $lnk.WorkingDirectory = $installDir
    $lnk.Save()

    # Start Menu
    $sm = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Banana Project Editor"
    New-Item -ItemType Directory -Path $sm -Force | Out-Null
    $lnk2 = $wsh.CreateShortcut("$sm\Banana Project Editor.lnk")
    $lnk2.TargetPath = "javaw.exe"
    $lnk2.Arguments  = "-jar `"$jarPath`""
    $lnk2.WorkingDirectory = $installDir
    $lnk2.Save()

    # Uninstall shortcut
    $lnkU = $wsh.CreateShortcut("$sm\Uninstall BPE.lnk")
    $lnkU.TargetPath = "powershell.exe"
    $lnkU.Arguments  = "-ExecutionPolicy Bypass -File `"$installDir\Uninstall-BPE.ps1`""
    $lnkU.Save()

    # Update shortcut
    $lnkUp = $wsh.CreateShortcut("$sm\Check for Updates.lnk")
    $lnkUp.TargetPath = "powershell.exe"
    $lnkUp.Arguments  = "-ExecutionPolicy Bypass -File `"$installDir\Update-BPE.ps1`""
    $lnkUp.Save()

    Write-OK "Shortcuts created."
}

function Add-ToPath($installDir) {
    Write-Step 5 5 "Adding to PATH..."
    $current = [System.Environment]::GetEnvironmentVariable("PATH","User")
    if ($current -notlike "*$installDir*") {
        [System.Environment]::SetEnvironmentVariable("PATH","$current;$installDir","User")
        $env:PATH += ";$installDir"
    }
    Write-OK "Added to PATH. You can now run 'bpe' from any terminal."
}

function Write-ExtraFiles($installDir) {
    # Write bpe.cmd launcher
    $launcher = "@echo off`r`njava -jar `"$installDir\BananaProjectEditor.jar`" %*"
    [System.IO.File]::WriteAllText("$installDir\bpe.cmd", $launcher)

    # Write version file
    $BPE_VERSION | Set-Content "$installDir\installed_version.txt" -Encoding ASCII

    # Write uninstaller
    $uninstall = @'
$installDir = "REPLACEME"
$ok = Read-Host "Uninstall BPE from $installDir ? (y/n)"
if ($ok -ne 'y') { exit }
Remove-Item "$([System.Environment]::GetFolderPath('Desktop'))\Banana Project Editor.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Banana Project Editor" -Recurse -Force -ErrorAction SilentlyContinue
foreach ($scope in @('User','Machine')) {
    $p = [System.Environment]::GetEnvironmentVariable('PATH',$scope)
    if ($p) { [System.Environment]::SetEnvironmentVariable('PATH',($p.Split(';') | Where-Object {$_ -ne $installDir}) -join ';',$scope) }
}
Start-Process cmd.exe -ArgumentList "/c timeout /t 2 & rd /s /q `"$installDir`"" -WindowStyle Hidden
Write-Host "Uninstalled." -ForegroundColor Green
Start-Sleep 2
'@
    $uninstall.Replace("REPLACEME", $installDir) | Set-Content "$installDir\Uninstall-BPE.ps1" -Encoding UTF8

    # Write updater
    $updater = @'
$REPO = "Banana-Toast-GH/BananaProjectEditor"
$INSTALL_DIR = "REPLACEME"
$installed = (Get-Content "$INSTALL_DIR\installed_version.txt" -ErrorAction SilentlyContinue).Trim()
Write-Host "Installed: $installed" -ForegroundColor DarkGray
$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent","BPE-Updater")
$latest = $wc.DownloadString("https://raw.githubusercontent.com/$REPO/main/version.txt").Trim()
Write-Host "Latest:    $latest" -ForegroundColor DarkGray
if ($installed -eq $latest) { Write-Host "Already up to date!" -ForegroundColor Green; Start-Sleep 2; exit }
$ok = Read-Host "Update to $latest? (y/n)"
if ($ok -ne 'y') { exit }
$zip = "$env:TEMP\BPE_update.zip"
$wc.DownloadFile("https://github.com/$REPO/releases/download/$latest/BananaProjectEditor.zip", $zip)
Add-Type -AssemblyName System.IO.Compression.FileSystem
Get-ChildItem $INSTALL_DIR -Exclude "installed_version.txt","Update-BPE.ps1","Uninstall-BPE.ps1","bpe.cmd" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
[System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $INSTALL_DIR)
$inner = Get-ChildItem $INSTALL_DIR -Directory | Where-Object {$_.Name -like "BananaProject*"} | Select-Object -First 1
if ($inner) { Get-ChildItem $inner.FullName | Move-Item -Destination $INSTALL_DIR -Force; Remove-Item $inner.FullName -Recurse -Force -ErrorAction SilentlyContinue }
Remove-Item $zip -Force -ErrorAction SilentlyContinue
$bat = Join-Path $INSTALL_DIR "build.bat"
if (Test-Path $bat) { Start-Process cmd.exe -ArgumentList "/c `"$bat`"" -WorkingDirectory $INSTALL_DIR -Wait -NoNewWindow }
$latest | Set-Content "$INSTALL_DIR\installed_version.txt" -Encoding ASCII
Write-Host "Updated to $latest!" -ForegroundColor Green
Start-Sleep 2
'@
    $updater.Replace("REPLACEME", $installDir) | Set-Content "$installDir\Update-BPE.ps1" -Encoding UTF8
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
Write-Header

Write-Host "  Install location:" -ForegroundColor White
Write-Host "  Press Enter for: $DEFAULT_INSTALL" -ForegroundColor DarkGray
$custom = Read-Host "  >"
$installDir = if ($custom.Trim()) { $custom.Trim() } else { $DEFAULT_INSTALL }
Write-Host ""

Ensure-Java
$zip = Download-BPE $installDir
if (-not $zip) { pause; exit 1 }
Install-Files $zip $installDir
Create-Shortcuts $installDir
Add-ToPath $installDir
Write-ExtraFiles $installDir

Write-Host ""
Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Banana Project Editor $BPE_VERSION installed!" -ForegroundColor Green
Write-Host "  Launch from your Desktop shortcut or run 'bpe'" -ForegroundColor White
Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Press any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
