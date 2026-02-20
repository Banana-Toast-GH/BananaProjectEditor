# BPE Web Installer Bootstrap
# Run: irm https://raw.githubusercontent.com/Banana-Toast-GH/BananaProjectEditor/main/install-web.ps1 | iex

$url = "https://raw.githubusercontent.com/Banana-Toast-GH/BananaProjectEditor/main/Install-BPE.ps1?t=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
$tmp = "$env:TEMP\Install-BPE-$(Get-Random).ps1"
(New-Object System.Net.WebClient).DownloadFile($url, $tmp)
powershell.exe -ExecutionPolicy Bypass -File $tmp
Remove-Item $tmp -Force -ErrorAction SilentlyContinue
