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

$containerName = "home-net-services"
if ($Operation -in @("stop", "restart")) {
    $ErrorActionPreference = "Ignore"

    Write-Host "`e[92mStopping `e[97;1m$containerName`e[0;92m container ..."
    Invoke-NativeCommand { docker stop $containerName 2>&1 } | Out-Null
    Invoke-NativeCommand { docker rm $containerName 2>&1 } | Out-Null
}

if ($Operation -in @("start", "restart")) {
    
    $gatewayIp = $config.home.gatewayAddress.Split('/')[0]
    (Get-Content "$PSScriptRoot/dhcpd.conf.dist" -Raw).
    Replace("__DOMAIN_NAME__", $config.home.dnsDomainName). `
        Replace("__DNS_SERVER__", $config.home.dnsServer). `
        Replace("__SUBNET__", $config.home.subnet). `
        Replace("__NETMASK__", $config.home.subnetMask). `
        Replace("__GATEWAY_IP__", $gatewayIp). `
        Replace("__DYNAMIC_RANGE_START__", $config.home.dynamicRangeStart). `
        Replace("__DYNAMIC_RANGE_END__", $config.home.dynamicRangeEnd) `
    | Out-File -Force "$PSScriptRoot/dhcpd.conf"

    Write-Host "`e[92mStarting `e[97;1m$containerName`e[0;92m container ..."
    $containerId = Invoke-NativeCommand {
        docker run -d `
            --network=none `
            --privileged `
            -v "$PSScriptRoot/dhcpd.conf:/etc/dhcp/dhcpd.conf" `
            --tmpfs /tmp --tmpfs /run --tmpfs /run/lock `
            --name $containerName `
            home-net-services 2>&1
    }
    
    Write-VerboseDryRun "Createing network namespace for the $containerName"
    $containerPid = Invoke-NativeCommand { docker inspect -f '{{.State.Pid}}' $containerId 2>&1 }

    $ns = $containerName
    # Creating namespace alias for the core-router container
    New-Item -ItemType Directory -Path "/var/run/netns" -Force | Out-Null
    New-Item -ItemType SymbolicLink -Path "/var/run/netns/$ns" -Value "/proc/$containerPid/ns/net" -Force | Out-Null

    Write-Host "`e[92mAdding `e[97;1mhome`e[0;92m macvlan network to the `e[97;1m$containerName`e[0;92m ..."
    New-NetMacVLanDevice -Name "home-n" -Parent "home-phy"
    Update-NetInterfaceNamespace "home-n" -TargetNamespace $ns
    Rename-NetInterface -Namespace $ns -CurrentName "home-n" -Name "home"
    $netServicesAddressIpCidr = "$($config.home.netServicesAddress)/$($config.home.gatewayAddress.split("/")[1])"
    Write-VerboseDryRun "Configuring address=$netServicesAddressIpCidr for the interface 'home', namespace=$ns"
    Invoke-NativeCommand { ip netns exec $ns ip link set home up 2>&1 } | Out-Null
    Invoke-NativeCommand { ip netns exec $ns ip addr add $netServicesAddressIpCidr dev home 2>&1 } | Out-Null
    
    Write-VerboseDryRun "Starting DHCP server service in the $containerName"
    Invoke-NativeCommand { docker exec -i $containerName systemctl start isc-dhcp-server 2>&1 } | Out-Null
}
