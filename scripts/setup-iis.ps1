# setup-iis.ps1

# What this script does:
#   1. Installs the Web-Server (IIS) Windows feature
#   2. Installs common IIS management tools
#   3. Writes a simple HTML page identifying which VM is serving it
#   4. Ensures the W3SVC (IIS) service is started and set to auto-start


$ErrorActionPreference = 'Stop'

# Install IIS
Write-Output "Installing IIS..."
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Confirm installation
$iis = Get-WindowsFeature -Name Web-Server
if ($iis.InstallState -ne 'Installed') {
    throw "IIS installation failed"
}
Write-Output "IIS installed successfully"

# Write a simple identification page
$hostname = $env:COMPUTERNAME
$html = @"
<!DOCTYPE html>
<html>
<head><title>Azure IIS VM</title></head>
<body style="font-family:Arial;padding:40px;background:#f0f4f8">
  <h1 style="color:#1F4E79">Azure Bicep — Secure Multi-Tier Infrastructure</h1>
  <p><strong>Server:</strong> $hostname</p>
  <p><strong>Status:</strong> IIS installed via Custom Script Extension</p>
  <p><strong>Time:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC</p>
</body>
</html>
"@

Set-Content -Path "C:\inetpub\wwwroot\index.html" -Value $html -Encoding UTF8
Write-Output "Default page written to C:\inetpub\wwwroot\index.html"

# Ensure IIS service is running
Start-Service W3SVC
Set-Service W3SVC -StartupType Automatic
Write-Output "W3SVC service started and set to auto-start"

Write-Output "Setup complete on $hostname"
