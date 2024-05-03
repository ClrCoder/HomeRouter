[CmdletBinding()]
param(
    [ValidateSet('start', 'stop', 'restart')]
    [Parameter(Mandatory)]
    [string]$Operation
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

. $PSScriptRoot/../../_scripts/utils.ps1

#$config = Get-HomeRouterConfig
$ns = "core-router"
if ($Operation -in @("stop", "restart")) {
    $ErrorActionPreference = "Ignore"
    Write-Verbose "Stopping pppoe-provider"
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { ip netns exec $ns poff pppoe-provider 2>&1 } | Out-Null
    }
}

if ($Operation -in @("start", "restart")) {
    Write-Verbose "Starting pppoe-provider"
    Invoke-NativeCommand { ip netns exec $ns ip link set wan-phy up 2>&1 } | Out-Null
    Invoke-NativeCommand { ip netns exec $ns pon pppoe-provider debug 2>&1 } | Out-Null
}
