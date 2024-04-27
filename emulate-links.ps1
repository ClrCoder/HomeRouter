[CmdletBinding(SupportsShouldProcess)]
param()

(. $PSScriptRoot/_scripts/utils.ps1)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# Emulating NIC connected to the WAN network
New-DummyLink "wan-phy" -SkipIfExist

# Emulating NIC connected to the Corp Network
New-DummyLink "corp-phy" -SkipIfExist

# Emulating NIC connected to the Home Network
New-DummyLink "home-phy" -SkipIfExist