[CmdletBinding(SupportsShouldProcess)]
param()

. $PSScriptRoot/../../_scripts/utils.ps1

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true


$tempNs = "wan-test"

New-NetNamespace -Name $tempNs
try {
    $config = Get-HomeRouterConfig
    Rename-NetInterface -MacAddress $config.wan.phyMacAddress -Name "wan-phy"
    Update-NetInterfaceNamespace -InterfaceName "wan-phy" -TargetNamespace $tempNs
    
    ip netns exec $tempNs pon pppoe-provider debug nodetach
}
finally {
    Update-NetInterfaceNamespace -InterfaceName "wan-phy" -SourceNamespace $tempNs
    Remove-NetNamespace -Name $tempNs
}
