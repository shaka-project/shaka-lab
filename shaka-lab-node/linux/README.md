# Shaka Lab Node for Linux

The Shaka Lab Node package provides Selenium grid nodes.
This is the Linux package.

For documentation on the package and configuration, or for links to other
platforms, see [the general docs](../README.md#readme).

**NOTE**: Browsers running in a Linux node **will not** be visible.

## Installation

TODO: Package distribution

## Updates

TODO: Package distribution

## Configuration

The config file is at `/etc/shaka-lab-node-config.yaml`.
See the [configuration section](#configuration) below for details.

## Restarting the service after editing the config

```sh
sudo systemctl restart shaka-lab-node
```

## Tailing logs

```sh
journalctl --no-hostname -u shaka-lab-node --follow
```

## Uninstallation

```sh
sudo apt remove -y shaka-lab-node
```
