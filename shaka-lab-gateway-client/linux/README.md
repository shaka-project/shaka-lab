# Shaka Lab Gateway Client

The Shaka Lab Gateway Client package allows Active Directory users from Shaka
Lab Gateway to log in.

This is the Linux package.

**NOTE**: Exactly one Linux device on your lab network must install the
[`shaka-lab-gateway`](https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme)
package.  Devices with the client package will connect to that gateway.  Do
not install the client package on the gateway itself.


## Requirements

Installing the package joins this machine to the domain, which requires:

- A host name of 15 characters or fewer.  This is a limit on Active Directory
  computer names.  If the name is longer, installation fails.
- An entry for this machine in the `devices` section of the gateway's config,
  so that `HOSTNAME.lab.shaka` resolves.
- A clock within 5 minutes of the gateway's.  The gateway does not serve time,
  so this machine needs its own time sync, such as `systemd-timesyncd`.

## Installation

```sh
curl -L https://shaka-project.github.io/shaka-lab/public.key | \
    sudo tee /etc/apt/trusted.gpg.d/shaka-lab.asc
echo deb https://shaka-project.github.io/shaka-lab/ stable main | \
    sudo tee /etc/apt/sources.list.d/shaka-lab.list
sudo apt update

# Configure dependencies to avoid prompting during installation.
# These are defaults that will be overwritten by shaka-lab-gateway-client
# anyway.
cat << EOF | sudo debconf-set-selections
krb5-config	krb5-config/default_realm	string	LAB.SHAKA
krb5-config	krb5-config/add_servers_realm	string	LAB.SHAKA
krb5-config	krb5-config/add_servers	boolean	false
EOF

# Configure your gateway's AD admin password before installation.  It is only
# used to join the domain, and is not kept afterward.  Use the "password" type,
# so debconf stores it where only root can read it.
cat << EOF | sudo debconf-set-selections
shaka-lab-gateway-client shaka-lab-gateway-client/active_directory_password password SOME_PASS
EOF

# Install the package, which will not have to prompt for anything thanks to
# the configuration above.
sudo apt -y install shaka-lab-gateway-client
```

## Updates

```sh
sudo apt update && sudo apt -y upgrade
```

### Upgrading from nslcd

Older versions of this package used `nslcd` to look up lab users.  The current
version uses `sssd` instead, and conflicts with `nslcd`, so `apt upgrade` will
hold it back until `nslcd` is removed.

Lab users can't log in while neither is installed, and that includes using
`sudo` through the `labadmins` group.  So start a root shell first, and do the
rest from there:

```sh
sudo -i

# Remove nslcd and its config, which contains the AD admin password.  Let
# libnss-ldapd remove itself from /etc/nsswitch.conf without asking.
echo "libnss-ldapd libnss-ldapd/clean_nsswitch boolean true" | \
    debconf-set-selections
apt purge -y nslcd libnss-ldapd libpam-ldapd nscd

# If this machine has never joined the domain, configure the AD admin password
# as in the installation instructions above.  Then upgrade.
apt -y install shaka-lab-gateway-client
```

## Configuration

There is no configuration necessary if you are connecting to the Active
Directory service from shaka-lab-gateway.

This package configures `systemd-resolved` to look up short host names in the
`lab.shaka` domain, so that `ssh HOSTNAME` finds `HOSTNAME.lab.shaka`.  The
gateway's DHCP server offers that domain too, but recent releases, such as
Ubuntu 26.04, ignore it by default.

## Logging in

Members of the `labusers` group in Active Directory can log in with their
Active Directory password.  Logging in with a password also gets the user a
Kerberos ticket, for logging in to other lab machines without a password.

## SSH access

Lab users can log in over SSH with their Active Directory password, or with a
Kerberos ticket and no password at all.  This package installs the OpenSSH
server if needed, and turns on Kerberos (GSSAPI) logins in
`/etc/ssh/sshd_config.d/shaka-lab-gateway-client.conf`.

To log in with Kerberos, get a ticket on the machine you are connecting from,
then connect with the machine's full name:

```sh
kinit USERNAME
ssh -l USERNAME HOSTNAME.lab.shaka
```

There is no need for `kinit` if you logged in to that machine with your
password.  Kerberos only works with the full name, not a short name or an IP
address.  Many SSH clients try Kerberos by default, including on Debian and
Ubuntu.  On others, set `GSSAPIAuthentication yes` in your SSH client config.

Your ticket follows you from one lab host to the next, so you only need
`kinit` once.  This package gets forwardable tickets by default, and its SSH
client config in `/etc/ssh/ssh_config.d/shaka-lab-gateway-client.conf`
forwards them to lab hosts (`*.lab.shaka`, `shaka-*`, and `gateway`).

## Managing Active Directory users

Managing Active Directory users is done on the gateway itself.  See
https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme

## Uninstallation

Removing the package leaves this machine joined to the domain:

```sh
sudo apt remove -y shaka-lab-gateway-client
```

Purging the package also removes `/etc/krb5.keytab` and the `sssd` config, so
lab users can no longer log in.  To delete this machine's computer account
from the domain as well, configure the AD admin password first, as in the
installation instructions above.  Otherwise, the package tells you how to
delete it on the gateway.

```sh
sudo apt purge -y shaka-lab-gateway-client
```
