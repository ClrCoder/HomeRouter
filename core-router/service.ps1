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


$config = Get-HomeRouterConfig

# The core router namespace name
$ns = "core-router"

if ($Operation -in @("stop", "restart")) {

    $ErrorActionPreference = "Ignore"

    Remove-NetNamespace $ns
    
    Write-VerboseDryRun "Removing default gateway for the router, ip=$($config.corp.gatewayIp), interface=corp"
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { ip route del default via $config.corp.gatewayIp dev corp 2>&1 } | Out-Null
    }

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

if ($Operation -in @("start", "restart")) {
    New-NetNamespace $ns
    if ($UseEmergencyWan) {
        $emergencyWanGatewayIp = (Get-NetInterfaceGateway -Interface "emergency-wan").gatewayIp
        $emergencyWanAddressCidr = (Get-NetInterfaceIpConfig -Interface "emergency-wan").addressCidr
        
        Write-Host "`e[92mEmulating `e[97;1mppp0`e[0;92m adapter from `e[97;1memergency-wan`e[0;92m..."
        Update-NetInterfaceNamespace "emergency-wan" -TargetNamespace $ns
        Rename-NetInterface -Namespace $ns -CurrentName "emergency-wan" -Name "ppp0"
        Write-VerboseDryRun "Configuring ppp0 adapter, that was renamed from 'emergency-wan'"
        if (!$WhatIfPreference) {
            Invoke-NativeCommand { ip netns exec $ns ip link set ppp0 up 2>&1 } | Out-Null
            Invoke-NativeCommand { ip netns exec $ns ip addr add $emergencyWanAddressCidr dev ppp0 2>&1 } | Out-Null
            Invoke-NativeCommand { ip netns exec $ns ip route add default via $emergencyWanGatewayIp dev ppp0 2>&1 } | Out-Null
        }
    }
    else {
        # TODO: Start pon in the namespace
    }

    # ----------- corp network base ----------------
    Write-Host "`e[92mConfiguring `e[97;1mcorp`e[0;92m core-router interface, gatewayIp=`e[97;1m$($config.corp.gatewayIp)`e[0;92m ..."
    New-NetMacVLanDevice -Name "corp-r" -Parent "corp-phy"
    Update-NetInterfaceNamespace "corp-r" -TargetNamespace $ns
    Rename-NetInterface -Namespace $ns -CurrentName "corp-r" -Name "corp"
    $gatewayIpCidr = "$($config.corp.gatewayIp)/$($config.corp.address.split("/")[1])"
    Write-VerboseDryRun "Configuring address=$gatewayIpCidr for the interface 'corp', namespace=$ns"
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { ip netns exec $ns ip link set corp up 2>&1 } | Out-Null
        Invoke-NativeCommand { ip netns exec $ns ip addr add $gatewayIpCidr dev corp 2>&1 } | Out-Null
    }

    Write-VerboseDryRun "Configuring default gateway for the router, ip=$($config.corp.gatewayIp), interface=corp"
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { ip route add default via $config.corp.gatewayIp dev corp 2>&1 } | Out-Null
    }

    # ----------- home network base ----------------
    Write-Host "`e[92mConfiguring `e[97;1mhome`e[0;92m core-router interface, gatewayIp=`e[97;1m$($config.home.gatewayAddress)`e[0;92m ..."
    Rename-NetInterface -MacAddress $config.home.phyMacAddress -Name "home-phy"
    New-NetMacVLanDevice -Name "home-r" -Parent "home-phy"
    Update-NetInterfaceNamespace "home-r" -TargetNamespace $ns
    Rename-NetInterface -Namespace $ns -CurrentName "home-r" -Name "home"
    $homeGatewayIpCidr = $config.home.gatewayAddress
    Write-VerboseDryRun "Configuring address=$homeGatewayIpCidr for the interface 'home', namespace=$ns"
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { ip netns exec $ns ip link set home up 2>&1 } | Out-Null
        Invoke-NativeCommand { ip netns exec $ns ip addr add $homeGatewayIpCidr dev home 2>&1 } | Out-Null
    }
}