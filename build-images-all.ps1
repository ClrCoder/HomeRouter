$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# We need ensure docker images starts from the latest ubuntu
docker pull ubuntu:noble

./corp/net-services/build-image.ps1

./home/net-services/build-image.ps1