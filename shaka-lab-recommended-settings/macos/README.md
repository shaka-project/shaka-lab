# Shaka Lab Recommended Settings for macOS

The Shaka Lab Recommended Settings package provides recommended OS settings for
a Shaka Lab environment.

This is the macOS package.

## Pre-requisites

 - Get Homebrew: [https://brew.sh/#install](https://brew.sh/#install)
 - You must grant full disk access to Terminal before proceeding.  Without this
   step, the package installation script is unable to make certain changes to
   OS settings.
   - [Disk access instructions](https://www.alfredapp.com/help/troubleshooting/indexing/terminal-full-disk-access/)
   - [Backup of disk access instructions](https://web.archive.org/web/20221216173704/https://www.alfredapp.com/help/troubleshooting/indexing/terminal-full-disk-access/) if the first link goes offline

## Installation

```sh
brew tap shaka-project/shaka-lab
brew install --cask shaka-lab-recommended-settings
```

## Updates

```sh
brew update && brew upgrade
```

## Uninstallation

```sh
brew uninstall --cask shaka-lab-recommended-settings
brew autoremove
```

**NOTE**: This package does not back up your original OS settings.
Uninstalling the package will not reset any modified settings to their previous
or default values.

## Specific Settings and Dependencies

Settings:
 - Remote access:
   - Enable SSH for all users
   - Enable VNC
 - Power:
   - Wake the system when the lid is opened (laptops)
   - Restart automatically on power loss
   - Never put the display to sleep
   - Never put the machine to sleep
   - Disable hibernation mode
   - Disable the "power nap" feature
 - Updates:
   - Check for OS updates automatically
   - Check for OS updates daily
   - Download OS updates in the background
   - Install OS updates automatically
   - Update apps automtically
   - Allow the App Store to reboot the machine when required for updates
 - Misc:
   - Allow unsigned binaries (necessary for shaka-lab-node and WebDriver)
