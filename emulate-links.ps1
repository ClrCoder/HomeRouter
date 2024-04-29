[CmdletBinding(SupportsShouldProcess)]
param()

. $PSScriptRoot/_scripts/utils.ps1

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

Copy-Item "$PSScriptRoot/config.json" "$PSScriptRoot/config.json.bak" -Force | Out-Null

Write-Host "`e[92mCreating `e[97;1mdummy0`e[0;92m interface that emulates `e[97;1mwan-phy`e[0;92m ..."
New-DummyLink "dummy0" -SkipIfExist
if (!$WhatIfPreference) {
    $output = Invoke-NativeCommand { ip link show dummy0 }
    $macAddress = $output[1].Trim().Split(" ")[1]
    $config = Get-Content "$PSScriptRoot/config.json" | ConvertFrom-Json -AsHashtable
    $config.wan.phyMacAddress = $macAddress
}
$config | ConvertTo-Json | Out-File "$PSScriptRoot/config.json" -Force


Write-Host "`e[92mCreating dummy `e[97;1mhome-phy`e[0;92m interface ..."
New-DummyLink "home-phy" -SkipIfExist
if (!$WhatIfPreference) {
    $output = Invoke-NativeCommand { ip link show home-phy }
    $macAddress = $output[1].Trim().Split(" ")[1]
    Copy-Item "$PSScriptRoot/config.json" "$PSScriptRoot/config.json.bak" -Force | Out-Null
    $config = Get-Content "$PSScriptRoot/config.json" | ConvertFrom-Json -AsHashtable
    $config.home.phyMacAddress = $macAddress
}
$config | ConvertTo-Json | Out-File "$PSScriptRoot/config.json" -Force
