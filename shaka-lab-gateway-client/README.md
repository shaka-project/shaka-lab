# Shaka Lab Gateway Client

The Shaka Lab Gateway Client package allows Active Directory users from Shaka
Lab Gateway to log in.

**NOTE**: This package may not be as appropriate for your own lab environment
as it is for ours.  For the Shaka team, this package is primarily a documented,
repeatable, and automated installation process for a critical asset in the lab.
Use it in your own setup if you wish, but at your own risk.  If installed
naively, this could conflict with existing services on your network.

**NOTE**: Exactly one Linux device on your lab network must install the
[`shaka-lab-gateway`](https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme)
package for devices with the client package to connect to.


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
Directory service from shaka-lab-gateway.  This package has no other intent.

## Managing Active Directory users

Managing Active Directory users is done on the gateway itself.  See
https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme

## Uninstallation

```sh
sudo apt remove -y shaka-lab-gateway-client
```
