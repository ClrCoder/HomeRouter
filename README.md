# HomeRouter project
## Terminology
- **Emergency Network** - the network for accessing the router on a static IP address via SSH
- **Emergency WAN** - the network that has DHCP, DNS and internet for the router setup and recovery
- **WAN Network** - the NIC that is connected to ONT (Optical Network Terminal)
- **Home Network** - the LAN that is used for home and entertainment tasks
- **Corp Network** - the LAN used for the work from home purposes

## Prerequisites
1) Ubuntu Server Minimal 24.04
1) Docker (built-in into the OS)
1) ssh-server
1) htop, mc
1) iproute2
1) PowerShell 7.4
1) tuned
## Development prerequisites
1) Visual Studio Code, remote SSH

