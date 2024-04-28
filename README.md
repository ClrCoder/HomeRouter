# HomeRouter project
## Terminology
- **Emergency Network** - the network that is useful for setup and emergency recovery of the router. If the router has an additional NIC interface, it can be connected to some existing network with DHCP and the Internet, and accessed via SSH.
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
