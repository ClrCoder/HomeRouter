[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$UseEmergencyWan
)

& "$PSScriptRoot/service.ps1" "start" -UseEmergencyWan:$UseEmergencyWan
& "$PSScriptRoot/service.ps1" "stop" -UseEmergencyWan:$UseEmergencyWan