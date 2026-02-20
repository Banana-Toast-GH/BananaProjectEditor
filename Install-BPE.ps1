#Requires -Version 5.1

$VERSION = "v0.3.8"
$REPO = "Banana-Toast-GH/BananaProjectEditor"
$ZIP_URL = "https://github.com/$REPO/releases/download/$VERSION/BananaProjectEditor.zip"
$INSTALL = "$env:LOCALAPPDATA\BananaProjectEditor"

Write-Host "Banana Project Editor Installer $VERSION" -ForegroundColor Yellow
Write-Host ""

# Java check
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Java not found. Install from https://adoptium.net" -ForegroundColor Red
    pause; exit 1
}
Write-Host "Java found." -ForegroundColor Green

# Ask install location
$custom = Read-Host "Install location (Enter for $INSTALL)"
if ($custom.Trim()) { $INSTALL = $custom.Trim() }

# Download
Write-Host "Downloading..." -ForegroundColor Cyan
$zip = "$env:TEMP\BPE.zip"
(New-Object System.Net.WebClient).DownloadFile($ZIP_URL, $zip)
Write-Host "Downloaded." -ForegroundColor Green

# Extract
Write-Host "Extracting..." -ForegroundColor Cyan
if (Test-Path $INSTALL) {
    try { Remove-Item $INSTALL -Recurse -Force -ErrorAction Stop }
    catch { Write-Host "Could not remove old install - will overwrite." -ForegroundColor Yellow }
}
New-Item -ItemType Directory -Path $INSTALL -Force | Out-Null
# Extract with overwrite
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $INSTALL)
} catch {
    # Overwrite existing files manually
    $zipObj = [System.IO.Compression.ZipFile]::OpenRead($zip)
    foreach ($entry in $zipObj.Entries) {
        $destPath = Join-Path $INSTALL $entry.FullName
        if ($entry.Name -eq "") {
            New-Item -ItemType Directory -Path $destPath -Force | Out-Null
        } else {
            New-Item -ItemType Directory -Path (Split-Path $destPath) -Force | Out-Null
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destPath, $true)
        }
    }
    $zipObj.Dispose()
}
Remove-Item $zip -Force

# Move inner folder up if needed
$inner = Get-ChildItem $INSTALL -Directory | Select-Object -First 1
if ($inner -and (Test-Path "$($inner.FullName)\build.bat")) {
    Get-ChildItem $inner.FullName | Move-Item -Destination $INSTALL -Force
    Remove-Item $inner.FullName -Recurse -Force
}

# Build
$bat = "$INSTALL\build.bat"
if (Test-Path $bat) {
    Write-Host "Building..." -ForegroundColor Cyan
    Start-Process cmd.exe -ArgumentList "/c `"$bat`"" -WorkingDirectory $INSTALL -Wait -NoNewWindow
}

# Desktop shortcut
$jar = "$INSTALL\BananaProjectEditor.jar"
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\Banana Project Editor.lnk")
$lnk.TargetPath = "javaw.exe"
$lnk.Arguments = "-jar `"$jar`""
$lnk.WorkingDirectory = $INSTALL
$lnk.Save()

# Start Menu
$sm = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Banana Project Editor"
New-Item -ItemType Directory -Path $sm -Force | Out-Null
$lnk2 = $wsh.CreateShortcut("$sm\Banana Project Editor.lnk")
$lnk2.TargetPath = "javaw.exe"
$lnk2.Arguments = "-jar `"$jar`""
$lnk2.WorkingDirectory = $INSTALL
$lnk2.Save()

# PATH
$path = [Environment]::GetEnvironmentVariable("PATH","User")
if ($path -notlike "*$INSTALL*") {
    [Environment]::SetEnvironmentVariable("PATH","$path;$INSTALL","User")
}

# Version file
$VERSION | Set-Content "$INSTALL\installed_version.txt"

Write-Host ""
Write-Host "Done! Banana Project Editor $VERSION installed." -ForegroundColor Green
Write-Host "Launch it from your Desktop shortcut." -ForegroundColor White
Write-Host ""
pause
