# BPE Web Installer Bootstrap
# Run this with:
#   irm https://raw.githubusercontent.com/Banana-Toast-GH/BananaProjectEditor/main/install-web.ps1 | iex

$url = "https://raw.githubusercontent.com/Banana-Toast-GH/BananaProjectEditor/main/Install-BPE.ps1"
$tmp = "$env:TEMP\Install-BPE.ps1"
(New-Object System.Net.WebClient).DownloadFile($url, $tmp)
& powershell.exe -ExecutionPolicy Bypass -File $tmp
