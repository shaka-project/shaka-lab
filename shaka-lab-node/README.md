# Selenium Node

The Selenium Node package is available for Linux, Windows, and macOS.


## Linux

Installation:

```sh
# TODO: download package
sudo dpkg -i shaka-lab-node*.deb
```

Updates:

```sh
# TODO: Linux updates
```

Configuration:

The config file is at `/etc/shaka-lab-node-config.yaml`.
See the [configuration section](#configuration) below for details.

Restarting the service after editing the config:

```sh
sudo systemctl restart shaka-lab-node
```

Viewing logs:

```sh
journalctl --no-hostname -u shaka-lab-node
```

Uninstallation:

```sh
sudo apt remove shaka-lab-node
```


## Windows

Pre-requisites:

 - Get Chocolatey: [https://docs.chocolatey.org/en-us/choco/setup](https://docs.chocolatey.org/en-us/choco/setup)

Installation:

```sh
# TODO: download package
# TODO: install package
```

Updates:

```sh
# TODO: Windows updates
```

Configuration:

The config file is at `c:\ProgramData\shaka-lab-node\node-config.yaml`.
See the [configuration section](#configuration) below for details.

Restarting the service after editing the config:

```sh
net stop shaka-lab-node
net start shaka-lab-node
```

Viewing logs:

```sh
# TODO: Windows logs
```

Uninstallation:

```sh
# TODO: Windows uninstall
```


## macOS

Pre-requisites:

 - Get Homebrew: [https://brew.sh/#install](https://brew.sh/#install)

Installation:

```sh
# TODO: macOS installation
```

Updates:

```sh
# TODO: macOS updates
```

Configuration:

The config file is at `/opt/homebrew/etc/shaka-lab-node-config.yaml`.
See the [configuration section](#configuration) below for details.

Restarting the service after editing the config:

```sh
/opt/homebrew/opt/shaka-lab-node/restart-services.sh
```

Viewing logs:

```sh
# TODO: macOS logs
```

Uninstallation:

```sh
# TODO: macOS uninstall
```


## Configuration

TODO: Explain node configuration

TODO: Explain debug logging


## Special node setup requirements

 - Tizen nodes require Docker, but can run on any OS.
 - Tizen TVs must be configured to accept commands from the IP of the device
   running the Tizen node.
 - Android nodes require `adb`, but can run on any OS.
 - Xbox One nodes require Visual Studio and must be run on Windows.