$script:HomeRouterConfig
function Write-VerboseDryRun {
    param(
        [string]$Message
    )
    
    if ($WhatIfPreference) {
        Write-Verbose "DryRun: $Message"
    }
    else {
        Write-Verbose $Message
    }
}

function Invoke-NativeCommand {
    param (
        [scriptblock]$Script,
        [ref]$ErrorCode #If this reference is specified, then 
    )

    $errorActionPreferenceBackup = $ErrorActionPreference
    $ErrorActionPreference = 'Ignore'
    try {
        $output = & $Script
        $ec = $LASTEXITCODE
        if ($ec) {
            if ($null -eq $ErrorCode) {
                if ($errorActionPreferenceBackup -ne 'SilentlyContinue') {
                    $output | Out-Default
                }
                throw "Error executing native command. ErrorCode=$ec"
            }
            else {
                $ErrorCode.Value = $ec
            }
        }
        return $output
    }
    finally {
        $ErrorActionPreference = $errorActionPreferenceBackup
    }
}
function Test-LinkExist {
    param(
        [Parameter(Mandatory)]
        [string]$LinkName
    )
    
    $errorCode = 0
    Invoke-NativeCommand { ip link show $LinkName 2>&1 } -ErrorCode ([ref]$errorCode) | Out-Null
    return !$errorCode
}

function Remove-Link {
    param(
        [Parameter(Mandatory)]
        [string]$LinkName,
        [switch]$SkipIfMissing
    )

    if ($SkipIfMissing -and !(Test-LinkExist $LinkName)) {
        return;
    }

    Write-VerboseDryRun "Removing link $LinkName"
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { ip link del $LinkName 2>&1 } | Out-Null
    }
}

function New-DummyLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LinkName,
        [switch]$SkipIfExist
    )

    if ($SkipIfExist -and (Test-LinkExist $LinkName)) {
        return;
    }

    Write-VerboseDryRun "Creating dummy link '$LinkName'"
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { ip link add $LinkName type dummy 2>&1 } | Out-Null
    }
}

function New-NetNamespace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Namespace
    )
    Write-VerboseDryRun "Creating network namespace '$Namespace'"
    
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { ip netns add $Namespace } | Out-Null
    }
}

function Remove-NetNamespace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Namespace
    )
    Write-VerboseDryRun "Removing network namespace '$Namespace'"
    
    if (!$WhatIfPreference) {
        Invoke-NativeCommand { ip netns del $Namespace } | Out-Null
    }
}

function Get-HomeRouterConfig {
    if (!$script:HomeRouterConfig) {
        $script:HomeRouterConfig = Get-Content "$PSScriptRoot/../config.json" -Raw | ConvertFrom-Json
        Write-Verbose ("Using Config:`n" + ($script:HomeRouterConfig | ConvertTo-Json))
    }
    return $script:HomeRouterConfig
}

function Rename-NetInterface {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MacAddress,
        [string]$Name
    )
    
    $output = Invoke-NativeCommand { ip link show }
    
    # --- ChatGPT owesome! ---
    # Split the output into lines and process each line
    $interfaceName = $null
    foreach ($line in $output -split "`n") {
        if ($line -match '^\d+: (\S+):') {
            # Captures the interface name from lines like "2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc..."
            $currentInterface = $matches[1]
        }
        if ($line -match 'link/ether ' + $macAddress) {
            # If the current line contains the MAC address, we've found the right interface
            $interfaceName = $currentInterface
            break
        }
    }
    # --- ChatGPT owesome! ---

    if (!$interfaceName) {
        throw "Interface with MAC address $macAddress not found"
    }

    Write-Verbose "Found current interface '$interfaceName' with $MacAddress"
    if ($interfaceName -eq $Name) {
        # Rename is not required
        return;
    }

    Write-Verbose "Renaming interface with '$interfaceName' to $Name"
    if (!$WhatIfPreference) {
        #Invoke-NativeCommand { ip link set dev $interfaceName down } | Out-Null
        Invoke-NativeCommand { ip link set dev $interfaceName name $Name } | Out-Null
        #Invoke-NativeCommand { ip link set dev $Name up } | Out-Null
    }
}

function Update-NetInterfaceNamespace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InterfaceName,
        [string]$SourceNamespace,
        [string]$TargetNamespace
    )
    
    if (!$SourceNamespace -and !$TargetNamespace) {
        throw "Either SourceNamespace and/or TargetNamespace must be specified"
    }

    $sourceNsDisplay = $SourceNamespace
    if (!$sourceNsDisplay) {
        $sourceNsDisplay = 'default'
    }

    $targetNsDisplay = $TargetNamespace
    if (!$targetNsDisplay) {
        $targetNsDisplay = 'default'
    }

    Write-VerboseDryRun "Moving interface $InterfaceName from '$sourceNsDisplay' to namespace '$targetNsDisplay'"
    if (!$WhatIfPreference) {
        $targetNs = $TargetNamespace
        if (!$targetNs) {
            $targetNs = "1"
        }
        if ($SourceNamespace) {
            Invoke-NativeCommand { ip netns exec $SourceNamespace ip link set dev $InterfaceName netns $targetNs } | Out-Null
        }
        else {
            Invoke-NativeCommand { ip link set dev $InterfaceName netns $targetNs } | Out-Null
        }
    }
}