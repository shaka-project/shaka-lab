# Shaka Lab Gateway Client

The Shaka Lab Gateway Client package allows Active Directory users from Shaka
Lab Gateway to log in.

This is the macOS package.

**NOTE**: Exactly one Linux device on your lab network must install the
[`shaka-lab-gateway`](https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme)
package.  Devices with the client package will connect to that gateway.

## Pre-requisites

 - Get Homebrew: [https://brew.sh/#install](https://brew.sh/#install)
 - You must grant full disk access to Terminal before proceeding.  Without this
   step, the package installation script is unable to make certain changes to
   OS settings.
   - [Disk access instructions](https://www.alfredapp.com/help/troubleshooting/indexing/terminal-full-disk-access/)
   - [Backup of disk access instructions](https://web.archive.org/web/20221216173704/https://www.alfredapp.com/help/troubleshooting/indexing/terminal-full-disk-access/) if the first link goes offline

## Installation

**NOTE**: When you install this package, you will be prompted for the Active
Directory Administrator password used to set up the Gateway.  This is necessary
to join the domain.

```sh
brew tap shaka-project/shaka-lab
brew install --cask shaka-lab-gateway-client
```

## Updates

```sh
brew update && brew upgrade
```

## Configuration

There is no configuration necessary if you are connecting to the Active
Directory service from shaka-lab-gateway.  This package has no other intent.

## Managing Active Directory users

Managing Active Directory users is done on the gateway itself.  See
https://github.com/shaka-project/shaka-lab/tree/main/shaka-lab-gateway#readme

## Uninstallation

**NOTE**: When you uninstall this package, you will be prompted for the Active
Directory Administrator password used to set up the Gateway.  This is necessary
to leave the domain.

```sh
brew uninstall --cask shaka-lab-gateway-client
brew autoremove
```
