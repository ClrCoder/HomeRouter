docker run --rm -it `
  --network=none `
  --privileged `
  --tmpfs /tmp --tmpfs /run --tmpfs /run/lock `
  --name corp-net-services `
  corp-net-services
