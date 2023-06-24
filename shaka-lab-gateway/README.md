# Shaka Lab Gateway

The Shaka Lab Gateway package provides lab network services, and is available
for **Linux only**.

This will install and configure the following services:
 - DHCP service (allocate LAN IPs to devices)
 - DNS service (resolve local device names)
 - Samba Active Directory service (user accounts across lab devices)
 - Optional networking routing config

**NOTE**: This package may not be as appropriate for your own lab environment
as it is for ours.  For the Shaka team, this package is primarily a documented,
repeatable, and automated installation process for a critical asset in the lab.
Use it in your own setup if you wish, but at your own risk.  If installed
naively, this could conflict with existing services on your network.

**NOTE**: To allow Active Directory users to log in on a device, install the
[`shaka-lab-gateway-client`](https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway-client#readme)
package.  This includes the gateway device itself.  To allow AD users to log
into the gateway, that device must also have the client package installed.


## Installation

```sh
curl -L https://shaka-project.github.io/shaka-lab/public.key | \
    sudo tee /etc/apt/trusted.gpg.d/shaka-lab.asc
echo deb https://shaka-project.github.io/shaka-lab/ stable main | \
    sudo tee /etc/apt/sources.list.d/shaka-lab.list
sudo apt update

# Configure dependencies to avoid prompting during installation.
# These are defaults that will be overwritten by shaka-lab-gateway anyway.
cat << EOF | sudo debconf-set-selections
krb5-config krb5-config/default_realm string
iptables-persistent iptables-persistent/autosave_v4 boolean false
iptables-persistent iptables-persistent/autosave_v6 boolean false
EOF

# Configure your lab and gateway details before installation.
# If lan_ip == lan_router, this device will also function as a router.
# Two interfaces are required for router mode.
# If you don't have a secondary interface, leave wan_interface blank.
cat << EOF | sudo debconf-set-selections
shaka-lab-gateway shaka-lab-gateway/lan_interface string enp47s0
shaka-lab-gateway shaka-lab-gateway/wan_interface string enp45s0
shaka-lab-gateway shaka-lab-gateway/lan_network string 192.168.0.0/24
shaka-lab-gateway shaka-lab-gateway/lan_ip string 192.168.0.1
shaka-lab-gateway shaka-lab-gateway/lan_router string 192.168.0.254
shaka-lab-gateway shaka-lab-gateway/dhcp_start string 192.168.0.10
shaka-lab-gateway shaka-lab-gateway/dhcp_end string 192.168.0.99
shaka-lab-gateway shaka-lab-gateway/active_directory_password string SOME_PASS
EOF

# Install the package, which will not have to prompt for anything thanks to
# the configuration above.
sudo apt -y install shaka-lab-gateway
```

## Updates

```sh
sudo apt update && sudo apt -y upgrade
```

## Configuration

Config files for various services are managed by a config templating system
called Total Perspective Vortex.

Modify `/etc/total-perspective-vortex/config.yaml` and read the docs at
https://github.com/joeyparrish/total-perspective-vortex for more details.

## Restarting services after editing the config

```sh
sudo total-perspective-vortex
```

## Creating Active Directory users

```sh
sudo labuser-create joeyparrish
```

## Adding Active Directory users to the admin group

```sh
sudo labuser-make-admin joeyparrish
```

## Removing Active Directory users from the admin group

```sh
sudo labuser-remove-admin joeyparrish
```

## Changing Active Directory user passwords

```sh
sudo labuser-change-password joeyparrish
```

## Deleting Active Directory users

```sh
sudo labuser-delete joeyparrish
```

## Uninstallation

```sh
sudo apt remove -y shaka-lab-gateway
```

## Notes

Our Intel NUC 12 hardware seems incapable of delivering DHCP responses on the
first interface.  We don't know why.  If you have a device with two interfaces,
and DHCP isn't working, please try swapping the roles of the two interfaces
(LAN & WAN).  If you're not operating your gateway in router mode, try
assigning the other interface as LAN anyway.
