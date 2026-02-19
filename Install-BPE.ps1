#Requires -Version 5.1
<#
.SYNOPSIS
    Banana Project Editor Installer v0.2.5
.DESCRIPTION
    Downloads, installs, and configures Banana Project Editor.
    Creates shortcuts, adds to PATH, and checks for Java.
#>

# ── Config ────────────────────────────────────────────────────────────────────
$BPE_VERSION    = "v0.2.5"
$BPE_REPO       = "Banana-Toast-GH/BananaProjectEditor"
$BPE_ZIP_URL    = "https://github.com/$BPE_REPO/releases/download/$BPE_VERSION/BananaProjectEditor.zip"
$BPE_VERSION_URL= "https://raw.githubusercontent.com/$BPE_REPO/main/version.txt"
$DEFAULT_INSTALL = "$env:LOCALAPPDATA\BananaProjectEditor"
$JAR_NAME       = "BananaProjectEditor.jar"
$EXE_LAUNCHER   = "bpe.cmd"

# ── Colors ────────────────────────────────────────────────────────────────────
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ██████╗ ██████╗ ███████╗" -ForegroundColor Yellow
    Write-Host "  ██╔══██╗██╔══██╗██╔════╝" -ForegroundColor Yellow
    Write-Host "  ██████╔╝██████╔╝█████╗  " -ForegroundColor Yellow
    Write-Host "  ██╔══██╗██╔═══╝ ██╔══╝  " -ForegroundColor Yellow
    Write-Host "  ██████╔╝██║     ███████╗" -ForegroundColor Yellow
    Write-Host "  ╚═════╝ ╚═╝     ╚══════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Banana Project Editor Installer" -ForegroundColor White
    Write-Host "  Version $BPE_VERSION" -ForegroundColor DarkGray
    Write-Host "  ─────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Step($n, $total, $msg) {
    Write-Host "  [" -NoNewline -ForegroundColor DarkGray
    Write-Host "$n/$total" -NoNewline -ForegroundColor Cyan
    Write-Host "] " -NoNewline -ForegroundColor DarkGray
    Write-Host $msg -ForegroundColor White
}

function Write-OK($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "    $msg"  -ForegroundColor DarkGray }

# ── Check if running as admin (needed for PATH & Program Files) ───────────────
function Test-Admin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ── Java check ────────────────────────────────────────────────────────────────
function Ensure-Java {
    Write-Step 1 6 "Checking Java..."
    $java = Get-Command java -ErrorAction SilentlyContinue
    if ($java) {
        $ver = & java -version 2>&1 | Select-String "version" | ForEach-Object { $_.ToString() }
        Write-OK "Java found: $ver"
        return $true
    }

    Write-Warn "Java not found. Downloading OpenJDK 21..."

    $jdkUrl  = "https://aka.ms/download-jdk/microsoft-jdk-21-windows-x64.msi"
    $jdkMsi  = "$env:TEMP\openjdk21.msi"

    try {
        Write-Info "Downloading OpenJDK 21 (~180MB)..."
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($jdkUrl, $jdkMsi)
        Write-Info "Installing OpenJDK 21 (silent)..."
        Start-Process msiexec.exe -ArgumentList "/i `"$jdkMsi`" /quiet /norestart ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome" -Wait
        Remove-Item $jdkMsi -Force -ErrorAction SilentlyContinue

        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("PATH","User")

        $java2 = Get-Command java -ErrorAction SilentlyContinue
        if ($java2) {
            Write-OK "OpenJDK 21 installed successfully."
            return $true
        } else {
            Write-Err "Java installation may have succeeded but 'java' not in PATH yet."
            Write-Info "Please restart your PC and re-run the installer if BPE won't launch."
            return $false
        }
    } catch {
        Write-Err "Failed to auto-install Java: $_"
        Write-Info "Please install Java manually from: https://adoptium.net"
        Write-Info "Then re-run this installer."
        return $false
    }
}

# ── Download ──────────────────────────────────────────────────────────────────
function Download-BPE($installDir) {
    Write-Step 2 6 "Downloading BPE $BPE_VERSION..."
    $zipPath = "$env:TEMP\BananaProjectEditor.zip"

    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent","BPE-Installer/$BPE_VERSION")
        Write-Info "From: $BPE_ZIP_URL"
        $wc.DownloadFile($BPE_ZIP_URL, $zipPath)
        Write-OK "Download complete."
        return $zipPath
    } catch {
        Write-Err "Download failed: $_"
        Write-Info "Check your internet connection or visit:"
        Write-Info "https://github.com/$BPE_REPO/releases"
        return $null
    }
}

# ── Extract & build ───────────────────────────────────────────────────────────
function Install-Files($zipPath, $installDir) {
    Write-Step 3 6 "Installing to $installDir ..."

    # Clean old install
    if (Test-Path $installDir) {
        Write-Info "Removing old installation..."
        Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null

    # Extract
    Write-Info "Extracting..."
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $installDir)
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Err "Extraction failed: $_"
        return $false
    }

    # Find extracted subfolder (zip may contain BananaProjectEditor\...)
    $inner = Get-ChildItem $installDir -Directory | Select-Object -First 1
    if ($inner -and (Test-Path "$($inner.FullName)\build.bat")) {
        Write-Info "Moving files up from subfolder..."
        Get-ChildItem $inner.FullName | Move-Item -Destination $installDir -Force
        Remove-Item $inner.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Build
    $buildBat = Join-Path $installDir "build.bat"
    if (Test-Path $buildBat) {
        Write-Info "Running build.bat..."
        $proc = Start-Process cmd.exe -ArgumentList "/c `"$buildBat`"" -WorkingDirectory $installDir -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            Write-Warn "build.bat exited with code $($proc.ExitCode) — JAR may still exist."
        } else {
            Write-OK "Build complete."
        }
    } else {
        Write-Warn "build.bat not found — skipping build step."
    }

    # Confirm JAR exists
    $jar = Join-Path $installDir $JAR_NAME
    if (Test-Path $jar) {
        Write-OK "BananaProjectEditor.jar ready."
        return $true
    } else {
        # Check recursively
        $found = Get-ChildItem $installDir -Recurse -Filter $JAR_NAME | Select-Object -First 1
        if ($found) {
            Write-OK "JAR found at: $($found.FullName)"
            return $true
        }
        Write-Warn "JAR not found after build — launcher will search at runtime."
        return $true
    }
}

# ── Write launcher CMD ────────────────────────────────────────────────────────
function Write-Launcher($installDir) {
    $launcherPath = Join-Path $installDir $EXE_LAUNCHER
    $jar = Join-Path $installDir $JAR_NAME
    $content = @"
@echo off
:: Banana Project Editor Launcher
:: Auto-generated by installer $BPE_VERSION
set "BPE_HOME=$installDir"
set "BPE_JAR=%BPE_HOME%\$JAR_NAME"
if not exist "%BPE_JAR%" (
    echo [BPE] JAR not found, searching...
    for /r "%BPE_HOME%" %%f in ($JAR_NAME) do set "BPE_JAR=%%f"
)
if not exist "%BPE_JAR%" (
    echo [BPE] ERROR: Cannot find $JAR_NAME in %BPE_HOME%
    pause
    exit /b 1
)
java -jar "%BPE_JAR%" %*
"@
    Set-Content -Path $launcherPath -Value $content -Encoding ASCII
    return $launcherPath
}

# ── Shortcuts ─────────────────────────────────────────────────────────────────
function Create-Shortcuts($installDir) {
    Write-Step 4 6 "Creating shortcuts..."

    $jarPath     = Join-Path $installDir $JAR_NAME
    $launcherPath= Join-Path $installDir $EXE_LAUNCHER
    $iconPath    = Join-Path $installDir "icon.ico"
    $wsh         = New-Object -ComObject WScript.Shell

    # Desktop shortcut
    $desktop = [System.Environment]::GetFolderPath("Desktop")
    $lnk     = $wsh.CreateShortcut("$desktop\Banana Project Editor.lnk")
    $lnk.TargetPath      = "javaw.exe"
    $lnk.Arguments       = "-jar `"$jarPath`""
    $lnk.WorkingDirectory= $installDir
    $lnk.Description     = "Banana Project Editor $BPE_VERSION"
    if (Test-Path $iconPath) { $lnk.IconLocation = $iconPath }
    $lnk.Save()
    Write-OK "Desktop shortcut created."

    # Start Menu shortcut
    $startMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Banana Project Editor"
    New-Item -ItemType Directory -Path $startMenu -Force | Out-Null

    $lnk2 = $wsh.CreateShortcut("$startMenu\Banana Project Editor.lnk")
    $lnk2.TargetPath      = "javaw.exe"
    $lnk2.Arguments       = "-jar `"$jarPath`""
    $lnk2.WorkingDirectory= $installDir
    $lnk2.Description     = "Banana Project Editor $BPE_VERSION"
    if (Test-Path $iconPath) { $lnk2.IconLocation = $iconPath }
    $lnk2.Save()

    # Start Menu uninstaller link
    $lnkU = $wsh.CreateShortcut("$startMenu\Uninstall BPE.lnk")
    $lnkU.TargetPath = "powershell.exe"
    $lnkU.Arguments  = "-ExecutionPolicy Bypass -File `"$installDir\Uninstall-BPE.ps1`""
    $lnkU.Save()
    Write-OK "Start Menu entries created."
}

# ── PATH ──────────────────────────────────────────────────────────────────────
function Add-ToPath($installDir) {
    Write-Step 5 6 "Adding BPE to PATH..."

    $scope = if (Test-Admin) { "Machine" } else { "User" }
    $current = [System.Environment]::GetEnvironmentVariable("PATH", $scope)

    if ($current -like "*$installDir*") {
        Write-OK "Already in PATH."
        return
    }

    [System.Environment]::SetEnvironmentVariable("PATH", "$current;$installDir", $scope)
    $env:PATH += ";$installDir"
    Write-OK "Added to $scope PATH. You can now run 'bpe' from any terminal."
}

# ── Write version file ────────────────────────────────────────────────────────
function Write-VersionFile($installDir) {
    $BPE_VERSION | Set-Content (Join-Path $installDir "installed_version.txt") -Encoding ASCII
}

# ── Write uninstaller ─────────────────────────────────────────────────────────
function Write-Uninstaller($installDir) {
    $content = @"
#Requires -Version 5.1
# BPE Uninstaller — auto-generated by installer $BPE_VERSION
`$installDir = "$installDir"
`$choice = Read-Host "Uninstall Banana Project Editor from `$installDir ? (y/n)"
if (`$choice -ne 'y') { exit 0 }

# Remove shortcuts
`$desktop   = [System.Environment]::GetFolderPath("Desktop")
`$startMenu = "`$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Banana Project Editor"
Remove-Item "`$desktop\Banana Project Editor.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item `$startMenu -Recurse -Force -ErrorAction SilentlyContinue

# Remove from PATH
foreach (`$scope in @("User","Machine")) {
    `$p = [System.Environment]::GetEnvironmentVariable("PATH", `$scope)
    if (`$p) {
        `$new = (`$p.Split(';') | Where-Object { `$_ -ne "`$installDir" }) -join ';'
        [System.Environment]::SetEnvironmentVariable("PATH", `$new, `$scope)
    }
}

# Remove install dir (schedule deletion on reboot since we're inside it)
Start-Process cmd.exe -ArgumentList "/c timeout /t 2 & rd /s /q `"`$installDir`"" -WindowStyle Hidden
Write-Host "Banana Project Editor uninstalled." -ForegroundColor Green
Write-Host "Press any key to exit..." -ForegroundColor DarkGray
`$null = `$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
"@
    Set-Content -Path (Join-Path $installDir "Uninstall-BPE.ps1") -Value $content -Encoding UTF8
}

# ── Auto-updater ──────────────────────────────────────────────────────────────
function Write-Updater($installDir) {
    $content = @"
#Requires -Version 5.1
# BPE Auto-Updater — checks GitHub for a newer version and installs it
`$REPO         = "$BPE_REPO"
`$VERSION_URL  = "https://raw.githubusercontent.com/`$REPO/main/version.txt"
`$INSTALL_DIR  = "$installDir"
`$INSTALLED    = (Get-Content "`$INSTALL_DIR\installed_version.txt" -ErrorAction SilentlyContinue).Trim()

Write-Host "Banana Project Editor Updater" -ForegroundColor Yellow
Write-Host "Installed: `$INSTALLED" -ForegroundColor DarkGray

try {
    `$wc = New-Object System.Net.WebClient
    `$wc.Headers.Add("User-Agent","BPE-Updater/`$INSTALLED")
    `$latest = `$wc.DownloadString(`$VERSION_URL).Trim()
    Write-Host "Latest:    `$latest" -ForegroundColor DarkGray
} catch {
    Write-Host "Could not reach GitHub. Check your connection." -ForegroundColor Red
    pause; exit 1
}

if (`$INSTALLED -eq `$latest) {
    Write-Host "You're already on the latest version!" -ForegroundColor Green
    Start-Sleep 2; exit 0
}

Write-Host "New version available: `$latest" -ForegroundColor Cyan
`$choice = Read-Host "Update now? (y/n)"
if (`$choice -ne 'y') { exit 0 }

`$zipUrl    = "https://github.com/`$REPO/releases/download/`$latest/BananaProjectEditor.zip"
`$zipPath   = "`$env:TEMP\BPE_update.zip"
Write-Host "Downloading `$latest..." -ForegroundColor White

try {
    `$wc2 = New-Object System.Net.WebClient
    `$wc2.Headers.Add("User-Agent","BPE-Updater/`$INSTALLED")
    `$wc2.DownloadFile(`$zipUrl, `$zipPath)
} catch {
    Write-Host "Download failed: `$_" -ForegroundColor Red
    pause; exit 1
}

# Extract over existing install
Write-Host "Extracting..." -ForegroundColor White
Add-Type -AssemblyName System.IO.Compression.FileSystem
Get-ChildItem `$INSTALL_DIR -Exclude "installed_version.txt","Update-BPE.ps1","Uninstall-BPE.ps1","bpe.cmd","Projects" |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
[System.IO.Compression.ZipFile]::ExtractToDirectory(`$zipPath, `$INSTALL_DIR)

# Move inner folder up if needed
`$inner = Get-ChildItem `$INSTALL_DIR -Directory | Where-Object { `$_.Name -like "BananaProject*" } | Select-Object -First 1
if (`$inner) {
    Get-ChildItem `$inner.FullName | Move-Item -Destination `$INSTALL_DIR -Force
    Remove-Item `$inner.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

Remove-Item `$zipPath -Force -ErrorAction SilentlyContinue

# Build
`$bat = Join-Path `$INSTALL_DIR "build.bat"
if (Test-Path `$bat) {
    Write-Host "Building..." -ForegroundColor White
    Start-Process cmd.exe -ArgumentList "/c `"`$bat`"" -WorkingDirectory `$INSTALL_DIR -Wait -NoNewWindow
}

# Write new version
`$latest | Set-Content "`$INSTALL_DIR\installed_version.txt" -Encoding ASCII
Write-Host "Updated to `$latest successfully!" -ForegroundColor Green
Start-Sleep 2
"@
    Set-Content -Path (Join-Path $installDir "Update-BPE.ps1") -Value $content -Encoding UTF8

    # Also add an Update shortcut to Start Menu
    try {
        $startMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Banana Project Editor"
        $wsh = New-Object -ComObject WScript.Shell
        $lnk = $wsh.CreateShortcut("$startMenu\Check for Updates.lnk")
        $lnk.TargetPath = "powershell.exe"
        $lnk.Arguments  = "-ExecutionPolicy Bypass -File `"$installDir\Update-BPE.ps1`""
        $lnk.Save()
    } catch {}
}

# ── Finish ────────────────────────────────────────────────────────────────────
function Show-Finish($installDir) {
    Write-Step 6 6 "Finalising..."
    Write-VersionFile $installDir
    Write-Uninstaller $installDir
    Write-Updater     $installDir
    Write-Host ""
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  ✓ Banana Project Editor $BPE_VERSION installed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  • Double-click the Desktop shortcut to launch" -ForegroundColor White
    Write-Host "  • Or run " -NoNewline -ForegroundColor White
    Write-Host "bpe" -NoNewline -ForegroundColor Cyan
    Write-Host " from any terminal" -ForegroundColor White
    Write-Host "  • Start Menu → Banana Project Editor → Check for Updates" -ForegroundColor White
    Write-Host "  • Installed to: $installDir" -ForegroundColor DarkGray
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════
Write-Header

# Ask for install location
Write-Host "  Install location:" -ForegroundColor White
Write-Host "  [Enter] = $DEFAULT_INSTALL" -ForegroundColor DarkGray
Write-Host "  [Type a path] = custom location" -ForegroundColor DarkGray
Write-Host ""
$customPath = Read-Host "  >"
$installDir = if ($customPath.Trim()) { $customPath.Trim() } else { $DEFAULT_INSTALL }
Write-Host ""

# Run steps
$javaOk = Ensure-Java
$zipPath = Download-BPE $installDir
if (-not $zipPath) { Write-Host ""; pause; exit 1 }

$ok = Install-Files $zipPath $installDir
if (-not $ok) { Write-Host ""; pause; exit 1 }

Write-Launcher $installDir | Out-Null
Create-Shortcuts $installDir
Add-ToPath $installDir
Show-Finish $installDir

Write-Host "  Press any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
