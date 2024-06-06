# Shaka Lab Cert Generator

The Shaka Lab Cert Generator package creates and renews certificates for
HTTPS-based testing.  This is necessary for testing features that require a
secure context, particularly on consumer electronics devices where we are
unable to install trusted certificates.

This package is available for **Linux only** and is intended to run **inside
a Google Compute Engine VM** with a default service account.  This works around
any organizational policies in Google Cloud that might prevent you from
exporting service account keys.  (This is relevant for Shaka at Google.)

_This package offers support for additional arguments to certbot to enable power
users to run it in other contexts.  But the intended environment of Google
Compute Engine is the only one we use for Shaka._

## Pre-requisites

It is assumed that:

1. You have registered a domain for your lab network.  (Ours is
   `shakalab.rocks`.)
2. You have a DNS record for one host on your lab network that will host the
   tests.  This is the host that lab devices will connect to.  It should have a
   public DNS `A` record that points to the host's internal lab IP address.  In
   the instructions below, your hostname should be filled in for `CERT_HOST`.
   (Ours is `karma.shakalab.rocks`.)
3. You have a Google Compute Engine VM running Debian or Ubuntu with full API
   access.  Under "API and identity management", "Service account" should refer
   to the default GCE service account for your project and "Cloud API access
   scopes" should say "Allow full access to all Cloud APIs".
4. Your default service account should have the "DNS Administrator" role
   assigned.
5. Your GCE instance has a way to SSH to the certificate host to transfer the
   certificates.

## Installation

```sh
curl -L https://shaka-project.github.io/shaka-lab/public.key | \
    sudo tee /etc/apt/trusted.gpg.d/shaka-lab.asc
echo deb https://shaka-project.github.io/shaka-lab/ stable main | \
    sudo tee /etc/apt/sources.list.d/shaka-lab.list
sudo apt update

# Configure your lab's details before installation to avoid prompting.
# If you want to pass additional arguments to certbot or the certbot-dns-google
# plugin, use certbot_args below.
cat << EOF | sudo debconf-set-selections
shaka-lab-cert-generator shaka-lab-cert-generator/cert_host string CERT_HOST
shaka-lab-cert-generator shaka-lab-cert-generator/certbot_args string 
EOF

# Install the package, which will not have to prompt for anything thanks to
# the configuration above.
sudo apt -y install shaka-lab-cert-generator
```

### SSH Configuration

To automatically transfer the certificates to another host, set up an
appropriate SSH config file at
`/opt/shaka-lab/shaka-lab-cert-generator/ssh.config` with the host `cert-host`.
Include any non-standard port numbers, jump proxies, usernames, and identity
files necessary to authenticate.  (Password authentication is not an option.)

This SSH config file, if it exists, should be owned by root and have
permissions set to `644`.  It will not be created for you.

Example configs:

```
Host cert-host
  # The actual hostname or IP of the host:
  Hostname hostname-or-ip-goes-here
  # Non-standard port number:
  Port 9245
  # Service account username allowed to write to the files:
  User shaka-lab-cert-receiver
  # A specific key, generated with ssh-keygen -f path and pre-shared
  # with cert-host in ~/.ssh/authorized_keys:
  IdentityFile /opt/shaka-lab/shaka-lab-cert-generator/cert-host-id
  IdentitiesOnly yes
  # Don't even attempt password authentication:
  PreferredAuthentications publickey
  # Don't prompt for new server keys:
  StrictHostKeyChecking accept-new
```

Or to use a jump proxy to connect through a gateway to reach the cert host:

```
Host lab-gateway
  # The actual hostname or IP of the gateway/proxy:
  Hostname hostname-or-ip-goes-here
  # Non-standard port number of the gateway:
  Port 9245
  # Service account username allowed to connect through the gateway (may be the
  # same as the cert-host user):
  User gateway-user
  # A specific key, generated with ssh-keygen -f path and pre-shared
  # with the gateway in ~/.ssh/authorized_keys (may be the same as the
  # cert-host key):
  IdentityFile /opt/shaka-lab/shaka-lab-cert-generator/gateway-id
  IdentitiesOnly yes
  # Don't even attempt password authentication:
  PreferredAuthentications publickey
  # Don't prompt for new server keys:
  StrictHostKeyChecking accept-new

Host cert-host
  # The hostname or IP within the lab:
  Hostname cert-host-hostname-or-ip-goes-here
  # Service account username allowed to write to the files:
  User shaka-lab-cert-receiver
  # A specific key, generated with ssh-keygen -f path and pre-shared
  # with cert-host in ~/.ssh/authorized_keys:
  IdentityFile /opt/shaka-lab/shaka-lab-cert-generator/cert-host-id
  IdentitiesOnly yes
  # Don't even attempt password authentication:
  PreferredAuthentications publickey
  # Don't prompt for new server keys:
  StrictHostKeyChecking accept-new
  # Command to proxy through lab-gateway:
  ProxyCommand ssh -W %h:%p lab-gateway
```

### SSH Authentication

A unique SSH key will be generated for you on installation in
`/opt/shaka-lab/shaka-lab-cert-generator/`, with the public key in
`cert-host-id.pub` and the private key in `cert-host-id`.  When using the
[`shaka-lab-cert-receiver` package](../shaka-lab-cert-receiver/README.md#readme)
(recommended) on the receiving device, you should copy the contents of
`cert-host-id.pub` to the receiving device's
`/opt/shaka-lab/shaka-lab-cert-receiver/.ssh/authorized_keys`.

After the initial SSH configuration and after authentication setup between the
two devices, you need to sync the certificates for the first time.  To do so,
run `/etc/letsencrypt/renewal-hooks/deploy/shaka-lab-certs.sh` as root.

## Updates

```sh
sudo apt update && sudo apt -y upgrade
```

## Configuration

To change domains or certificate hostnames, it is simplest to purge and
reinstall the package:

```sh
sudo apt remove --purge shaka-lab-cert-generator
sudo apt install shaka-lab-cert-generator
```

## Uninstallation

```sh
sudo apt remove -y shaka-lab-cert-generator
```
