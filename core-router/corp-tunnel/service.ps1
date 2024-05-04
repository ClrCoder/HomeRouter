[CmdletBinding()]
param(
    [ValidateSet('start', 'stop', 'restart')]
    [Parameter(Mandatory)]
    [string]$Operation
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

. $PSScriptRoot/../../_scripts/utils.ps1

$config = Get-HomeRouterConfig

$ns = "core-router"
if ($Operation -in @("stop", "restart")) {
    $ErrorActionPreference = "Ignore"
    Write-Verbose "Stopping corp-tunnel"
    Invoke-NativeCommand { ip netns exec $ns ip link delete corp-tunnel 2>&1 } | Out-Null
}

if ($Operation -in @("start", "restart")) {
    Write-Verbose "Starting corp-tunnel"

    Invoke-NativeCommand { ip netns exec $ns ip link add dev corp-tunnel type wireguard 2>&1 } | Out-Null
    # Possible but not recommended. Peers can reside in the networks with decreased MTU
    # Default MTU is 1420
    #    Invoke-NativeCommand { ip netns exec $ns ip link set mtu 1440 dev corp-tunnel 2>&1 } | Out-Null
    Invoke-NativeCommand { ip netns exec $ns ip address add dev corp-tunnel $config.corpTunnel.address 2>&1 } | Out-Null
    Invoke-NativeCommand { ip netns exec $ns wg setconf corp-tunnel $PSScriptRoot/wg.config 2>&1 } | Out-Null
    Invoke-NativeCommand { ip netns exec $ns ip link set up dev corp-tunnel 2>&1 } | Out-Null
}
