# Shaka Lab Gateway Client

The Shaka Lab Gateway Client package allows Active Directory users from Shaka
Lab Gateway to log in.

This is the Linux package.

**NOTE**: Exactly one Linux device on your lab network must install the
[`shaka-lab-gateway`](https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme)
package.  Devices with the client package will connect to that gateway.


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
nslcd	nslcd/ldap-reqcert	select	never
nslcd	nslcd/ldap-uris	string	ldaps://localhost
nslcd	nslcd/ldap-base	string	dc=lab,dc=shaka
libnss-ldapd	libnss-ldapd/nsswitch	multiselect	passwd, group, shadow
krb5-config	krb5-config/default_realm	string	LAB.SHAKA
krb5-config	krb5-config/add_servers_realm	string	LAB.SHAKA
krb5-config	krb5-config/add_servers	boolean	false
EOF

# Configure your gateway's AD admin password before installation.
cat << EOF | sudo debconf-set-selections
shaka-lab-gateway-client shaka-lab-gateway-client/active_directory_password string SOME_PASS
EOF

# Install the package, which will not have to prompt for anything thanks to
# the configuration above.
sudo apt -y install shaka-lab-gateway-client
```

## Updates

```sh
sudo apt update && sudo apt -y upgrade
```

## Configuration

There is no configuration necessary if you are connecting to the Active
Directory service from shaka-lab-gateway.

## SSH access

Lab users can log in over SSH with their Active Directory password, or with a
Kerberos ticket and no password at all.  This package installs the OpenSSH
server if needed, joins this machine to the domain, and turns on Kerberos
(GSSAPI) logins in `/etc/ssh/sshd_config.d/shaka-lab-gateway-client.conf`.

To log in with Kerberos, get a ticket once on the machine you are connecting
from, then connect with the machine's full name:

```sh
kinit USERNAME
ssh -l USERNAME HOSTNAME.lab.shaka
```

Kerberos only works with the full name, not a short name or an IP address.
Many SSH clients try Kerberos by default, including on Debian and Ubuntu.  On
others, set `GSSAPIAuthentication yes` in your SSH client config.

Joining the domain requires:

- A host name of 15 characters or fewer.  This is a limit on Active Directory
  computer names.  If the name is longer, the package skips the join and
  prints a warning.  Rename the machine, then reinstall the package.
- An entry for this machine in the `devices` section of the gateway's config,
  so that `HOSTNAME.lab.shaka` resolves.
- A clock within 5 minutes of the gateway's.  The gateway does not serve time,
  so this machine needs its own time sync, such as `systemd-timesyncd`.

## Managing Active Directory users

Managing Active Directory users is done on the gateway itself.  See
https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme

## Uninstallation

Removing the package leaves this machine joined to the domain:

```sh
sudo apt remove -y shaka-lab-gateway-client
```

Purging the package also deletes this machine's computer account from the
domain and removes `/etc/krb5.keytab`:

```sh
sudo apt purge -y shaka-lab-gateway-client
```
