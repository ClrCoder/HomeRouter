[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('start', 'stop', 'restart')]
    [Parameter(Mandatory)]
    [string]$Operation,
    [switch]$UseEmergencyWan
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

. $PSScriptRoot/../../_scripts/utils.ps1

$config = Get-HomeRouterConfig

$containerName = "corp-net-services"
if ($Operation -in @("stop", "restart")) {
    $ErrorActionPreference = "Ignore"

    Write-Host "`e[92mStopping `e[97;1m$containerName`e[0;92m container ..."
    Invoke-NativeCommand { docker stop $containerName 2>&1 } | Out-Null
    Invoke-NativeCommand { docker rm $containerName 2>&1 } | Out-Null
}

if ($Operation -in @("start", "restart")) {
    
    (Get-Content "$PSScriptRoot/dhcpd.conf.dist" -Raw).
    Replace("__DOMAIN_NAME__", $config.corp.dnsDomainName). `
        Replace("__DNS_SERVER__", $config.corp.dnsServer). `
        Replace("__SUBNET__", $config.corp.subnet). `
        Replace("__NETMASK__", $config.corp.subnetMask). `
        Replace("__GATEWAY_IP__", $config.corp.gatewayIp). `
        Replace("__DYNAMIC_RANGE_START__", $config.corp.dynamicRangeStart). `
        Replace("__DYNAMIC_RANGE_END__", $config.corp.dynamicRangeEnd) `
    | Out-File -Force "$PSScriptRoot/dhcpd.conf"

    Write-Host "`e[92mStarting `e[97;1m$containerName`e[0;92m container ..."
    $containerId = Invoke-NativeCommand {
        docker run -d `
            --network=none `
            --privileged `
            -v "$PSScriptRoot/dhcpd.conf:/etc/dhcp/dhcpd.conf" `
            --tmpfs /tmp --tmpfs /run --tmpfs /run/lock `
            --name $containerName `
            corp-net-services 2>&1
    }
    
    Write-VerboseDryRun "Createing network namespace for the $containerName"
    $containerPid = Invoke-NativeCommand { docker inspect -f '{{.State.Pid}}' $containerId 2>&1 }

    $ns = $containerName
    # Creating namespace alias for the core-router container
    New-Item -ItemType Directory -Path "/var/run/netns" -Force | Out-Null
    New-Item -ItemType SymbolicLink -Path "/var/run/netns/$ns" -Value "/proc/$containerPid/ns/net" -Force | Out-Null

    Write-Host "`e[92mAdding `e[97;1mcorp`e[0;92m macvlan network to the `e[97;1m$containerName`e[0;92m ..."
    New-NetMacVLanDevice -Name "corp-n" -Parent "corp-phy"
    Update-NetInterfaceNamespace "corp-n" -TargetNamespace $ns
    Rename-NetInterface -Namespace $ns -CurrentName "corp-n" -Name "corp"
    $netServicesAddressIpCidr = "$($config.corp.netServicesAddress)/$($config.corp.address.split("/")[1])"
    Write-VerboseDryRun "Configuring address=$netServicesAddressIpCidr for the interface 'corp', namespace=$ns"
    Invoke-NativeCommand { ip netns exec $ns ip link set corp up 2>&1 } | Out-Null
    Invoke-NativeCommand { ip netns exec $ns ip addr add $netServicesAddressIpCidr dev corp 2>&1 } | Out-Null
    
    Write-VerboseDryRun "Starting DHCP server service in the $containerName"
    Invoke-NativeCommand { docker exec -i $containerName systemctl start isc-dhcp-server 2>&1 } | Out-Null
}
