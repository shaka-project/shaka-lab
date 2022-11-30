# Shaka Lab Node for macOS

The Shaka Lab Node package provides Selenium grid nodes.
This is the macOS package.

For documentation on the package and configuration, or for links to other
platforms, see [the general docs](../README.md#readme).

**NOTE**: Browsers running in a macOS node **will** be visible.

## Pre-requisites

 - Get Homebrew: [https://brew.sh/#install](https://brew.sh/#install)

## Installation

TODO: Package distribution

## Updates

TODO: Package distribution

## Configuration

The config file is at `/opt/homebrew/etc/shaka-lab-node-config.yaml`.
See the [configuration section](../README.md#configuration) of the general doc.

## Restarting the service after editing the config

```sh
/opt/homebrew/opt/shaka-lab-node/restart-services.sh
```

## Tailing logs

```sh
tail -f /opt/homebrew/var/log/shaka-lab-node.err.log
```

## Uninstallation

```sh
/opt/homebrew/opt/shaka-lab-node/stop-services.sh
brew uninstall shaka-lab-node
```
