# Shaka Lab Node for Linux

The Shaka Lab Node package provides Selenium grid nodes.
This is the Linux package.

For documentation on the package and configuration, or for links to other
platforms, see [the general docs](../README.md#readme).

**NOTE**: Browsers running in a Linux node **will not** be visible.

## Installation

```sh
curl -L https://shaka-project.github.io/shaka-lab/public.key | \
    sudo tee /etc/apt/trusted.gpg.d/shaka-lab.asc
echo deb https://shaka-project.github.io/shaka-lab/ stable main | \
    sudo tee /etc/apt/sources.list.d/shaka-lab.list
sudo apt update
sudo apt install -y shaka-lab-node
```

## Updates

```sh
sudo apt update && sudo apt -y upgrade
```

## Configuration

The config file is at `/etc/shaka-lab-node-config.yaml`.
See the [configuration section](../README.md#configuration) of the general doc.

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
