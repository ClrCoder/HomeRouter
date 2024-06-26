
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
    Replace("__ADDRESS__", $config.corp.address).
    Replace("__DNS_SERVERS__", $config.corp.dnsServer) `
    | Out-File -Force "/etc/systemd/network/1020-corp.network"

    # --------- Wan interface ------------------
    Write-Host "`e[92mConfiguring `e[97;1mwan`e[0;92m interface..."
    (Get-Content "core-router/wan-pppoe/chap-secrets" -Raw).
    Replace("__USER_NAME__", $config.wan.userName).
    Replace("__PASSWORD__", $config.wan.password) `
    | Out-File -Force "/etc/ppp/chap-secrets"
    Write-VerboseDryRun "Setting permissions for /etc/ppp/chap-secrets"
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { chmod 600 /etc/ppp/chap-secrets 2>&1 } | Out-Null
    }

    New-Item -ItemType Directory "/etc/ppp/peers" -Force | Out-Null
    (Get-Content "core-router/wan-pppoe/pppoe-provider" -Raw).
    Replace("__USER_NAME__", $config.wan.userName) `
    | Out-File -Force "/etc/ppp/peers/pppoe-provider"

    # --------- core-router ------------------
    Write-Host "`e[92mConfiguring `e[97;1mcore-router`e[0;92m systemd services..."
        (Get-Content "core-router/core-router.service" -Raw).
    Replace("__PROJ_ROOT__", $PSScriptRoot) `
    | Out-File -Force "/etc/systemd/system/core-router.service"
    
    Write-VerboseDryRun "Reloading and enabling systemd 'core-router' service..."
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { systemctl daemon-reload 2>&1 } | Out-Null
        Invoke-NativeCommand { systemctl enable core-router 2>&1 } | Out-Null
    }

    # --------- wan-pppoe ------------------
    Write-Host "`e[92mConfiguring `e[97;1mwan-pppoe`e[0;92m systemd services..."
        (Get-Content "core-router/wan-pppoe/wan-pppoe.service" -Raw).
    Replace("__PROJ_ROOT__", $PSScriptRoot) `
    | Out-File -Force "/etc/systemd/system/wan-pppoe.service"
    
    Write-VerboseDryRun "Reloading and enabling systemd 'wan-pppoe' service..."
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { systemctl daemon-reload 2>&1 } | Out-Null
        Invoke-NativeCommand { systemctl enable wan-pppoe 2>&1 } | Out-Null
    }

    # --------- corp-tunnel ------------------
    Write-Host "`e[92mConfiguring `e[97;1mcorp-tunnel`e[0;92m systemd services..."
    (Get-Content "core-router/corp-tunnel/corp-tunnel.service" -Raw).
    Replace("__PROJ_ROOT__", $PSScriptRoot) `
    | Out-File -Force "/etc/systemd/system/corp-tunnel.service"
    
    Write-VerboseDryRun "Reloading and enabling systemd 'corp-tunnel' service..."
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { systemctl daemon-reload 2>&1 } | Out-Null
        Invoke-NativeCommand { systemctl enable corp-tunnel 2>&1 } | Out-Null
    }

    # --------- corp-net-services ------------------
    Write-Host "`e[92mConfiguring `e[97;1mcorp-net-services`e[0;92m systemd services..."
    (Get-Content "corp/net-services/corp-net-services.service" -Raw).
    Replace("__PROJ_ROOT__", $PSScriptRoot) `
    | Out-File -Force "/etc/systemd/system/corp-net-services.service"

    Write-VerboseDryRun "Reloading and enabling systemd 'corp-net-services' service..."
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { systemctl daemon-reload 2>&1 } | Out-Null
        Invoke-NativeCommand { systemctl enable corp-net-services 2>&1 } | Out-Null
    }

    # --------- home-net-services ------------------
    Write-Host "`e[92mConfiguring `e[97;1mhome-net-services`e[0;92m systemd services..."
        (Get-Content "home/net-services/home-net-services.service" -Raw).
    Replace("__PROJ_ROOT__", $PSScriptRoot) `
    | Out-File -Force "/etc/systemd/system/home-net-services.service"
    
    Write-VerboseDryRun "Reloading and enabling systemd 'home-net-services' service..."
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { systemctl daemon-reload 2>&1 } | Out-Null
        Invoke-NativeCommand { systemctl enable home-net-services 2>&1 } | Out-Null
    }

}
catch {
    Pop-Location | Out-Null
}
