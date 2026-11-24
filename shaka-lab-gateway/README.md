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

**NOTE**: To allow Active Directory users to log in on other devices, install
the
[`shaka-lab-gateway-client`](https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway-client#readme)
package on them.  Don't install it on the gateway itself.  This package lets
AD users log into the gateway on its own, and conflicts with the client
package, which would join the domain from the domain controller and could
reset the domain controller's own machine account.


## Installation

```sh
# Remove the repo setup from older versions of these instructions.
sudo rm -f /etc/apt/sources.list.d/shaka-lab.list /etc/apt/trusted.gpg.d/shaka-lab.asc
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://shaka-project.github.io/shaka-lab/public.key | \
    sudo tee /etc/apt/keyrings/shaka-lab.asc
cat << EOF | sudo tee /etc/apt/sources.list.d/shaka-lab.sources
Types: deb
URIs: https://shaka-project.github.io/shaka-lab/
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/shaka-lab.asc
EOF
sudo apt update

# Configure dependencies to avoid prompting during installation.
# These are defaults that will be overwritten by shaka-lab-gateway anyway.
cat << EOF | sudo debconf-set-selections
krb5-config krb5-config/default_realm string
iptables-persistent iptables-persistent/autosave_v4 boolean false
iptables-persistent iptables-persistent/autosave_v6 boolean false
nslcd nslcd/ldap-uris string ldapi://%2Fvar%2Flib%2Fsamba%2Fprivate%2Fldap_priv%2Fldapi
nslcd nslcd/ldap-base string cn=users,dc=lab,dc=shaka
nslcd nslcd/ldap-auth-type select none
nslcd nslcd/ldap-starttls boolean false
libnss-ldapd libnss-ldapd/nsswitch multiselect passwd, group
EOF

# Configure your lab and gateway details before installation.
# If lan_ip == lan_router, this device will also function as a router.
# Two interfaces are required for router mode.
# If you don't have a secondary interface, leave wan_interface blank.
# The AD admin password is only used to create the domain.  Use the "password"
# type for it, so debconf stores it where only root can read it.  With the
# "string" type, it would end up in /var/cache/debconf/config.dat, which
# anyone can read.
cat << EOF | sudo debconf-set-selections
shaka-lab-gateway shaka-lab-gateway/lan_interface string enp47s0
shaka-lab-gateway shaka-lab-gateway/wan_interface string enp45s0
shaka-lab-gateway shaka-lab-gateway/lan_network string 192.168.0.0/24
shaka-lab-gateway shaka-lab-gateway/lan_ip string 192.168.0.1
shaka-lab-gateway shaka-lab-gateway/lan_router string 192.168.0.254
shaka-lab-gateway shaka-lab-gateway/dhcp_start string 192.168.0.10
shaka-lab-gateway shaka-lab-gateway/dhcp_end string 192.168.0.99
shaka-lab-gateway shaka-lab-gateway/active_directory_password password SOME_PASS
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

Each entry under `devices` gets a DNS name, and a reserved IP if it has a
`mac`.  Names of machines that join the Active Directory domain must be 15
characters or less.

To give a device other names, list them in `aliases`:

```yaml
devices:
  shaka-linux1:
    ip: 192.168.0.201
    mac: "AA:BB:CC:DD:EE:FF"
    aliases:
      - selenium-grid
```

Aliases become DNS CNAME records for the device's name.  They don't get
reverse (PTR) records or DHCP reservations.  Don't add an alias as another
device with the same IP: that gives the IP several PTR records, which DNS
returns in rotation, so Kerberos clients that look up PTRs ask for the wrong
principal and fail with "Server not found in Kerberos database".  An alias
can't match any device name or another alias.

## Restarting services after editing the config

```sh
sudo total-perspective-vortex
```

## Logging into the gateway

Members of the `labusers` group can log into the gateway with their Active
Directory accounts, including over SSH with a Kerberos ticket, and members of
`labadmins` can use `sudo`.  Other accounts in the domain, such as
`Administrator`, can't log in.  Local accounts are not affected.

Users and groups have the same names and IDs as on lab clients.  `nslcd` reads
them from Active Directory through Samba's privileged local socket, which
needs no password.  Passwords are checked with Kerberos, which also gives the
user a ticket.  (Winbind isn't used for either, since on a domain controller it
always names users `LAB\user`.)  Kerberos logins use the gateway's host keys,
which the package exports from Active Directory to `/etc/krb5.keytab`.

As on lab clients, Kerberos tickets on the gateway are forwardable, and SSH
forwards them to lab hosts (`*.lab.shaka`, `shaka-*`, and `gateway`), so users
can SSH onward from there without a password.

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

## Letting Windows forward Kerberos tickets to lab machines

Windows only forwards a user's Kerberos ticket to machines that Active
Directory trusts for delegation.  Without a forwarded ticket, a user who logs
into a lab machine from Windows with Kerberos can't use Kerberos from there to
reach other machines.  Other clients forward tickets either way.

Trust one machine, by its host name:

```sh
sudo labmachine-trust shaka-linux2
```

Trust every machine in the domain, except domain controllers such as the
gateway itself.  Machines that are already trusted are skipped, and the ones
that were changed are listed at the end:

```sh
sudo labmachine-trust --all
```

Stop trusting a machine:

```sh
sudo labmachine-untrust shaka-linux2
```

A Windows client that already has a ticket for a machine keeps using it, so
run `klist purge` on the client after changing a machine's trust, or wait for
the ticket to expire.

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
