# Shaka Lab Gateway Client

The Shaka Lab Gateway Client package allows Active Directory users from Shaka
Lab Gateway to log in.

This is the Windows package.

**NOTE**: Exactly one Linux device on your lab network must install the
[`shaka-lab-gateway`](https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme)
package.  Devices with the client package will connect to that gateway.

## Pre-requisites

 - Get Chocolatey: [https://docs.chocolatey.org/en-us/choco/setup](https://docs.chocolatey.org/en-us/choco/setup)

## Installation

**NOTE**: When you install this package, you will be prompted for the Active
Directory Administrator password used to set up the Gateway.  This is necessary
to join the domain.

```sh
choco source add -n=shaka-lab -s=https://chocolatey.shakalab.rocks/
choco install shaka-lab-gateway-client
```

## Updates

```sh
choco upgrade -y shaka-lab-gateway-client
```

## Configuration

There is no configuration necessary if you are connecting to the Active
Directory service from shaka-lab-gateway.

## SSH access

Lab users can log in over SSH with their Active Directory password.  This
package installs and starts the Windows OpenSSH server if needed, and removes
the `Match Group administrators` block from the end of the stock
`sshd_config`.  That block makes the SSH server look up each user's groups
before authenticating them, which fails for domain users and drops the
connection.  Removing it also means admin accounts use their own
`authorized_keys` files instead of a shared one.

**NOTE**: SSH key logins do not work for domain users yet.  If a domain user
has a `.ssh\authorized_keys` file, the SSH server drops their connection
instead of falling back to a password, so they cannot log in over SSH at all.
Local accounts are not affected.

## Managing Active Directory users

Managing Active Directory users is done on the gateway itself.  See
https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme

## Uninstallation

**NOTE**: When you uninstall this package, you will be prompted for the Active
Directory Administrator password used to set up the Gateway.  This is necessary
to leave the domain.

Uninstalling does not restore the `sshd_config` block removed during
installation.

```sh
choco uninstall -y shaka-lab-gateway-client
```
