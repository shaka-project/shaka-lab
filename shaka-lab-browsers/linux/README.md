# Shaka Lab Browsers for Linux

The Shaka Lab Browsers package is a meta-package that installs all major
browsers for a Shaka Lab environment.

This is the Linux package.

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

# The recommended-settings package is a pre-requisite, and configures some
# additional repos that are needed to install browsers.  This must be installed
# first and separately from the browsers package.
sudo apt install -y shaka-lab-recommended-settings

# The browsers package depends on third-party browser packages from those
# additional repos.
sudo apt install -y shaka-lab-browsers
```

## Updates

```sh
sudo apt update && sudo apt -y upgrade
```

**NOTE**: This package does not control the update of any browsers.
However, updating packages generally via the above command will update the
browser packages.

## Uninstallation

```sh
sudo apt remove -y shaka-lab-browsers firefox google-chrome microsoft-edge
```

## Specific Browsers Installed

 - Firefox
 - Google Chrome
 - Microsoft Edge
