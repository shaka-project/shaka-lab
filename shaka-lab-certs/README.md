# Shaka Lab Certs

The Shaka Lab Certs package creates and renews certificates for HTTPS-based
testing.  This is necessary for testing features that require a secure context,
particularly on consumer electronics devices where we are unable to install
trusted certificates.

This package is available for **Linux only**.

## Pre-requisites

It is assumed that:

1. You have registered a domain for your lab network at Google Domains.  In the
   instructions below, your domain should be filled in for `DNS_ZONE`.  (Ours
   is `shakalab.rocks`.)
2. You have a DNS record for one host on your lab network that will host the
   tests.  This is the host that lab devices will connect to.  It should have a
   public DNS `A` record that points to the host's internal lab IP address.  In
   the instructions below, your hostname should be filled in for `CERT_HOST`.
   (Ours is `karma.shakalab.rocks`.)
3. You have an ACME DNS API token from Google Domains for the lab domain.  This
   allows certbot to automate the DNS challenge that proves you own the domain
   for which you are generating certificates.  To acquire such the token, log
   into Google Domains, click the domain, then click "Security" on the left.
   Find "ACME DNS API" on the right, click "Create token", then copy it to your
   clipboard.  In the instructions below, your token should be filled in for
   `GOOGLE_DOMAINS_TOKEN`.  Do not disclose this token to anyone.

## Installation

```sh
curl -L https://shaka-project.github.io/shaka-lab/public.key | \
    sudo tee /etc/apt/trusted.gpg.d/shaka-lab.asc
echo deb https://shaka-project.github.io/shaka-lab/ stable main | \
    sudo tee /etc/apt/sources.list.d/shaka-lab.list
sudo apt update

# Configure your lab's details before installation to avoid prompting.
cat << EOF | sudo debconf-set-selections
shaka-lab-certs shaka-lab-certs/dns_zone string DNS_ZONE
shaka-lab-certs shaka-lab-certs/google_domains_token password GOOGLE_DOMAINS_TOKEN
shaka-lab-certs shaka-lab-certs/cert_host string CERT_HOST
EOF

# Install the package, which will not have to prompt for anything thanks to
# the configuration above.
sudo apt -y install shaka-lab-certs
```

## Updates

```sh
sudo apt update && sudo apt -y upgrade
```

## Configuration

To update your token, you may edit `/etc/letsencrypt/google-domains.ini`.

To change domains or certificate hostnames, it is simplest to purge and
reinstall the package:

```sh
sudo apt remove --purge shaka-lab-certs
sudo apt install shaka-lab-certs
```

## Uninstallation

```sh
sudo apt remove -y shaka-lab-certs
```
