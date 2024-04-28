[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('start', 'stop', 'restart')]
    [Parameter(Mandatory)]
    [string]$Operation,
    [switch]$UseEmergencyWan
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

. $PSScriptRoot/../_scripts/utils.ps1
. $PSScriptRoot/functions.ps1


# The core router namespace name
$ns = "core-router"

# Creating namespace
if ($Operation -in @("stop", "restart")) {
    $ErrorActionPreference = "Ignore"

    try {

    }
    finally {
        Remove-NetNamespace $ns
        
        if ($UseEmergencyWan) {
            Write-VerboseDryRun "Reconfiguring emergency-wan adapter"
            if (!$WhatIfPreference) {
                Start-Sleep -Seconds 1
                Invoke-NativeCommand { networkctl reconfigure emergency-wan 2>&1 } | Out-Null
            }
        }
        else {
            # TODO:
        }
    }
}

if ($Operation -in @("start", "restart")) {
    New-NetNamespace $ns
    if ($UseEmergencyWan) {
        $emergencyWanGatewayIp = (Get-NetInterfaceGateway -Interface "emergency-wan").gatewayIp
        $emergencyWanAddressCidr = (Get-NetInterfaceIpConfig -Interface "emergency-wan").addressCidr
        Update-NetInterfaceNamespace "emergency-wan" -TargetNamespace $ns
        Rename-NetInterface -Namespace $ns -CurrentName "emergency-wan" -Name "ppp0"
        Write-VerboseDryRun "Configuring ppp0 adapter, that was renamed from 'emergency-wan'"
        if(!$WhatIfPreference) {
            Invoke-NativeCommand { ip netns exec $ns ip link set ppp0 up 2>&1 } | Out-Null
            Invoke-NativeCommand { ip netns exec $ns ip addr add $emergencyWanAddressCidr dev ppp0 2>&1 } | Out-Null
            Invoke-NativeCommand { ip netns exec $ns ip route add default via $emergencyWanGatewayIp dev ppp0 2>&1 } | Out-Null
        }
    }
    else {
        
    }
}