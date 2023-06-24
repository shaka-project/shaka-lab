# Shaka Lab Node

The Shaka Lab Node package provides Selenium grid nodes, and is available for:

 - [Linux](linux/README.md#readme)
 - [Windows](windows/README.md#readme)
 - [macOS](macos/README.md#readme)

Click a platform above for platform-specific instructions on installation,
updating, config file locations, tailing logs, and uninstallation.


## Configuration

Selenium node configuration happens in two parts:
  1. Selenium node templates in `node-templates.yaml`
  2. A configuration that instantiates those templates in
     `shaka-lab-node-config.yaml`.

For details on templates, see [node-templates.md](node-templates.md).

For details on config files, see [shaka-lab-node-config.md](shaka-lab-node-config.md).


## Special node setup requirements

 - Browser nodes require those browsers to be separately installed.
   - See the [`shaka-lab-browsers`](../shaka-lab-browsers/README.md#readme)
     package to simplify setup
 - Tizen nodes require Docker, but can run on any OS.
 - Tizen TVs must be configured to accept commands from the IP of the device
   running the Tizen node.
 - Android nodes require `adb`, but can run on any OS.
 - Xbox One nodes require Visual Studio and must be run on Windows.
