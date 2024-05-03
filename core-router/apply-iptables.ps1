[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$NoAutoRollback
)

. $PSScriptRoot/../_scripts/utils.ps1

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$config = Get-HomeRouterConfig
$env:PPP_STATIC_IP = $config.wan.pppStaticIp

# Saving ip-tables state
$ipTablesBackupFile = [System.IO.Path]::GetTempFileName()

$ns = "core-router"

Invoke-NativeCommand { ip netns exec $ns iptables-save 2>&1 } | Out-File $ipTablesBackupFile
if ($LASTEXITCODE) {
    throw "Error running iptables-save"
}

try {

    # Apply rules
    $output = Invoke-NativeCommand { ip netns exec $ns run-parts $PSScriptRoot/iptables.d 2>&1 }
    if ($output) {
        Write-Verbose $output
    }

    $rulesApplied = $true

    if (!$NoAutoRollback) {
        # Performing auto-rollback
        Write-Host "Waiting for 15 seconds before rollback rules, press CTRL+C to apply now" -ForegroundColor Red
        Start-Sleep 15
        $rulesApplied = $false
    }
}
finally {
    if (!$rulesApplied) {
        Write-Host "Rolling-back iptables changes..."
        Invoke-NativeCommand { ip netns exec $ns iptables-restore $ipTablesBackupFile 2>&1 }
    }
}
