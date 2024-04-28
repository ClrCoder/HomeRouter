[CmdletBinding(SupportsShouldProcess)]
param()

. $PSScriptRoot/_scripts/utils.ps1

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# Emulating NIC connected to the WAN network
New-DummyLink "dummy0" -SkipIfExist
$output = Invoke-NativeCommand { ip link show dummy0 }
$macAddress = $output[1].Trim().Split(" ")[1]
Copy-Item "$PSScriptRoot/config.json" "$PSScriptRoot/config.json.bak" -Force | Out-Null
$config = Get-Content "$PSScriptRoot/config.json" | ConvertFrom-Json -AsHashtable
$config.wan.phyMacAddress = $macAddress
$config | ConvertTo-Json | Out-File "$PSScriptRoot/config.json" -Force
