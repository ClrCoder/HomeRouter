Push-Location $PSScriptRoot
try {
    $env:DOCKER_BUILTKIT=1
    docker build . -t home-net-services
}
finally {
    Pop-Location
}
