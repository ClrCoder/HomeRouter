docker run --rm -it `
  --network=none `
  --privileged `
  --tmpfs /tmp --tmpfs /run --tmpfs /run/lock `
  --name home-net-services `
  home-net-services
