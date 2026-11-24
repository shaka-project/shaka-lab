# Shaka Lab Node for Linux

The Shaka Lab Node package provides Selenium grid nodes.
This is the Linux package.

For documentation on the package and configuration, or for links to other
platforms, see [the general docs](../README.md#readme).

**NOTE**: Browsers running in a Linux node **will not** be visible.

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
