Write-Host "Building home/net-services docker image..." -ForegroundColor Green

Push-Location $PSScriptRoot
try {
    $env:DOCKER_BUILTKIT=1
    docker build . -t home-net-services
}
finally {
    Pop-Location
}
