# Shaka Lab Node for macOS

The Shaka Lab Node package provides Selenium grid nodes.
This is the macOS package.

For documentation on the package and configuration, or for links to other
platforms, see [the general docs](../README.md#readme).

**NOTE**: Browsers running in a macOS node **will** be visible, and autologin
is required.  ([shaka-lab-recommended-settings](../../shaka-lab-recommended-settings/README.md#readme)
takes care of this for you.)  Browsers will run as the user that is logged in
on the GUI at the time this package is installed, so that should be the
autologin user.

**NOTE**: The autologin GUI user and the user running `brew` do not have to be
the same.

## Pre-requisites

 - Get Homebrew: [https://brew.sh/#install](https://brew.sh/#install)

## Installation

```sh
brew tap shaka-project/shaka-lab
brew install shaka-lab-node
```

## Updates

```sh
brew update && brew upgrade shaka-lab-node
```

## Configuration

The config file is at `/etc/shaka-lab-node-config.yaml`.
See the [configuration section](../README.md#configuration) of the general doc.

## Restarting the service after editing the config

```sh
sudo /opt/shaka-lab-node/restart-services.sh
```

## Tailing logs

```sh
tail -f /opt/shaka-lab-node/logs/stderr.log
```

## Uninstallation

```sh
sudo /opt/shaka-lab-node/stop-services.sh
brew uninstall shaka-lab-node
```
