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
to join the domain.  Before joining, the package syncs the clock, since the
domain rejects computers whose clocks are more than 5 minutes off.

```sh
choco source add -n=shaka-lab -s=https://chocolatey.shakalab.rocks/
choco install shaka-lab-gateway-client
```

**NOTE**: Restart the computer after installing to finish joining the domain.
The package doesn't restart it for you.

## Updates

```sh
choco upgrade -y shaka-lab-gateway-client
```

## Configuration

There is no configuration necessary if you are connecting to the Active
Directory service from shaka-lab-gateway.

## SSH access

Lab users can log in over SSH with their Active Directory password, or with a
Kerberos ticket and no password at all.  This package installs and starts the
Windows OpenSSH server if needed, and makes two changes to the stock
`sshd_config`:

 - It removes the `Match Group administrators` block from the end.  That block
   makes the SSH server look up each user's groups before authenticating them,
   which fails for domain users and drops the connection.  Removing it also
   means admin accounts use their own `authorized_keys` files instead of a
   shared one.
 - It turns on `GSSAPIAuthentication`, which allows Kerberos logins.

To log in with Kerberos, get a ticket, then ssh:

```sh
kinit
ssh HOSTNAME
```

Kerberos only works with the canonical name, not an alias or IP address.  Many
SSH clients try Kerberos by default.  If yours does not, set
`GSSAPIAuthentication yes` in your SSH client config.

**NOTE**: SSH key logins do not work for domain users.  For a key login,
Windows asks the domain controller for a ticket on the user's behalf.  Current
Windows releases make that request in a form Samba's domain controller does
not support (`PA-S4U-X509-USER`, see CVE-2026-20849).  Worse, if a domain user
has a `.ssh\authorized_keys` file, the SSH server drops their connection
instead of falling back to a password, so they cannot log in over SSH at all.
Use Kerberos instead.  Local accounts are not affected.

A domain user logged in to this computer already has a Kerberos ticket from
their Windows login, so they can SSH to other lab machines without a password
or `kinit`.

This package configures Windows' SSH client for lab hosts, in a marked block in
`C:\ProgramData\ssh\ssh_config`.  It applies to `gateway`, to names starting
with `shaka-`, and to any name ending in `.lab.shaka`, matching the Linux
package.  For a lab host with some other name, use its full name in the
`lab.shaka` domain.

For those hosts:

 - It sends your user name without the `LAB\` prefix, which other lab machines
   would not recognize.
 - It turns on Kerberos (GSSAPI) logins, which are off by default.
 - It forwards your Kerberos ticket, so you can SSH onward from there without a
   password.  Windows only forwards a ticket to a host that is trusted for
   delegation in Active Directory.  Otherwise the login still works, but you
   arrive without a ticket.  If a host became trusted for delegation after you
   last connected to it, Windows keeps using its cached ticket for that host,
   so run `klist purge` (or log off and on again) before connecting.

Settings in your own `.ssh\config` take precedence.

## Admin rights

Members of the Active Directory group `labadmins` are administrators on every
computer with this package installed.  The package adds `LAB\labadmins` to the
local Administrators group.

Over SSH, administrators get full admin rights without any extra step, so
there is no need for an equivalent of `sudo`.  At the console, Windows asks
them to confirm before running something as administrator.

Keep a local administrator account as well.  Domain accounts can't log in if
the gateway is down, or after the computer leaves the domain.

## DNS registration

The package stops Windows from registering this computer's addresses in DNS,
by setting `DisableDynamicUpdate` in the registry.  The gateway's DNS zone is
generated from the lab config and refuses updates, so registration only fills
the gateway's logs with failures.  Lab names come from the gateway config
instead.

## Managing Active Directory users

Managing Active Directory users is done on the gateway itself.  See
https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme

## Uninstallation

**NOTE**: When you uninstall this package, you will be prompted for the Active
Directory Administrator password used to set up the Gateway.  This is necessary
to leave the domain.

Uninstalling removes `LAB\labadmins` from the local Administrators group,
turns DNS registration back on, and removes the SSH client settings block from
`ssh_config`.  It does not restore the `sshd_config` changes made during
installation.  If leaving the domain fails, for example because of a mistyped
password, `LAB\labadmins` keeps its admin rights and the computer stays in the
domain.

Uninstall while logged in as a local administrator.  After the computer leaves
the domain, domain accounts can't log in to it.

```sh
choco uninstall -y shaka-lab-gateway-client
```

**NOTE**: Restart the computer after uninstalling to finish leaving the domain.
The package doesn't restart it for you.
