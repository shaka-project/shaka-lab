# Shaka Lab Node for macOS

The Shaka Lab Node package provides Selenium grid nodes.
This is the macOS package.

For documentation on the package and configuration, or for links to other
platforms, see [the general docs](../README.md#readme).

**NOTE**: Browsers running in a macOS node **will** be visible.

## Pre-requisites

 - Get Homebrew: [https://brew.sh/#install](https://brew.sh/#install)

## Installation

```sh
brew tap shaka-project/shaka-lab
brew install shaka-lab-node
$(brew --prefix)/opt/shaka-lab-node/restart-services.sh
```

## Updates

```sh
brew update && brew upgrade
$(brew --prefix)/opt/shaka-lab-node/restart-services.sh
```

## Configuration

The config file is at `/opt/homebrew/etc/shaka-lab-node-config.yaml` on Arm and
`/usr/local/etc/shaka-lab-node-config.yaml` on Intel.
See the [configuration section](../README.md#configuration) of the general doc.

## Restarting the service after editing the config

```sh
$(brew --prefix)/opt/shaka-lab-node/restart-services.sh
```

## Tailing logs

```sh
tail -f $(brew --prefix)/var/log/shaka-lab-node.err.log
```

## Uninstallation

```sh
$(brew --prefix)/opt/shaka-lab-node/stop-services.sh
brew uninstall shaka-lab-node
```
