Write-Host "Building corp/net-services docker image..." -ForegroundColor Green

Push-Location $PSScriptRoot
try {
    $env:DOCKER_BUILTKIT=1
    docker build . -t corp-net-services
}
finally {
    Pop-Location
}
