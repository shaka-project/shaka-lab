# Shaka Lab Gateway Client

The Shaka Lab Gateway Client package allows Active Directory users from Shaka
Lab Gateway to log in.

This is the macOS package.

**NOTE**: Exactly one Linux device on your lab network must install the
[`shaka-lab-gateway`](https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme)
package.  Devices with the client package will connect to that gateway.

## Pre-requisites

 - Get Homebrew: [https://brew.sh/#install](https://brew.sh/#install)

## Installation

**NOTE**: When you install this package, you will be prompted for the Active
Directory Administrator password used to set up the Gateway.  This is necessary
to join the domain.

```sh
brew tap shaka-project/shaka-lab
brew trust shaka-project/shaka-lab
brew install shaka-lab-gateway-client
```

## Updates

```sh
brew update && brew upgrade shaka-lab-gateway-client
```

## Configuration

There is no configuration necessary if you are connecting to the Active
Directory service from shaka-lab-gateway.  This package has no other intent.

## Lab user logins

Lab users (members of the Active Directory group `labusers`) can log in over
SSH.  If Remote Login is limited to certain users, this package adds
`labusers` to the allowed list.

Lab admins (members of the Active Directory group `labadmins`) are local
admins, and can use `sudo`.

macOS only creates home directories for Active Directory users on a GUI
login.  So this package installs a service that creates a home directory for
each lab user.  It runs every 5 minutes, so a new lab user may have to wait a
few minutes after being created on the gateway before logging in.

## SSH access

Lab users can log in over SSH with their Active Directory password, or with a
Kerberos ticket and no password at all.  This package turns on Kerberos
(GSSAPI) logins in `/etc/ssh/sshd_config.d/200-shaka-lab-gateway-client.conf`.

To log in with Kerberos, get a ticket, then ssh:

```sh
kinit
ssh HOSTNAME
```

Kerberos only works with the canonical name, not an alias or IP address.  Many
SSH clients try Kerberos by default.  If yours does not, set
`GSSAPIAuthentication yes` in your SSH client config.

Your ticket follows you from one lab host to the next, so you only need
`kinit` once.  This package's SSH client config in
`/etc/ssh/ssh_config.d/200-shaka-lab-gateway-client.conf` forwards tickets to
lab hosts (`*.lab.shaka`, `shaka-*`, and `gateway`).

## Managing Active Directory users

Managing Active Directory users is done on the gateway itself.  See
https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme

## Uninstallation

Uninstalling removes this package's files, but leaves this machine joined to
the domain.  Lab admins keep their admin rights, lab users keep SSH access, and
the log in `/var/log/shaka-lab-gateway-client.log` stays.  Upgrades uninstall
the old version first, so this keeps an upgrade from cutting anyone off.

```sh
brew uninstall shaka-lab-gateway-client
brew autoremove
```

To also revoke those rights, remove the log, and leave the domain, uninstall
with `--zap`.  This prompts for the Active Directory Administrator password
used to set up the Gateway.

```sh
brew uninstall --zap shaka-lab-gateway-client
brew autoremove
```

Either way, lab users' home directories in `/Users` are left in place.
