
[CmdletBinding(SupportsShouldProcess)]
param(
)

. $PSScriptRoot/_scripts/utils.ps1

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$config = Get-HomeRouterConfig

Push-Location $PSScriptRoot
try {
    
    # --------- Emergency Wan Interface ---------
    Write-Host "`e[92mConfiguring `e[97;1memergency wan`e[0;92m interface..."
    if ($config.emergency.enabled) {
        (Get-Content "emergency/0100-emergency-wan.link" -Raw).
        Replace("00:00:00:00:00:00", $config.emergency.macAddress) `
        | Out-File -Force "/etc/systemd/network/0100-emergency-wan.link"
        Copy-Item "emergency/0100-emergency-wan.network" -Destination "/etc/systemd/network/" -Force
    }
    else {
        Remove-Item -Force "/etc/systemd/network/0100-emergency-wan.link" -ErrorAction SilentlyContinue
        Remove-Item -Force "/etc/systemd/network/0100-emergency-wan.network" -ErrorAction SilentlyContinue
    }

    # --------- Corp base Interfaces ------------------
    Write-Host "`e[92mConfiguring base `e[97;1mcorp`e[0;92m interfaces..."
    
    (Get-Content "core-router/corp-base/1000-corp-phy.link" -Raw).
    Replace("00:00:00:00:00:00", $config.corp.phyMacAddress) `
    | Out-File -Force "/etc/systemd/network/1000-corp-phy.link"

    Copy-Item "core-router/corp-base/1010-corp-phy.network" -Destination "/etc/systemd/network/" -Force
    Copy-Item "core-router/corp-base/1010-corp.netdev" -Destination "/etc/systemd/network/" -Force

    (Get-Content "core-router/corp-base/1020-corp.network" -Raw).
    Replace("__ADDRESS__", $config.corp.address) `
    | Out-File -Force "/etc/systemd/network/1020-corp.network"

    # --------- Wan interface ------------------
    Write-Host "`e[92mConfiguring `e[97;1mwan`e[0;92m interface..."
    (Get-Content "core-router/wan-pppoe/chap-secrets" -Raw).
    Replace("__USER_NAME__", $config.wan.userName).
    Replace("__PASSWORD__", $config.wan.password) `
    | Out-File -Force "/etc/ppp/chap-secrets"
    Write-VerboseDryRun "Setting permissions for /etc/ppp/chap-secrets"
    if (!$WhatIfPreference){
        Invoke-NativeCommand { chmod 600 /etc/ppp/chap-secrets } | Out-Null
    }

    New-Item -ItemType Directory "/etc/ppp/peers" -Force | Out-Null
    (Get-Content "core-router/wan-pppoe/pppoe-provider" -Raw).
    Replace("__USER_NAME__", $config.wan.userName) `
    | Out-File -Force "/etc/ppp/peers/pppoe-provider"
}
catch {
    Pop-Location | Out-Null
}
