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
