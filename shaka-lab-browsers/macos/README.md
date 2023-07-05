# Shaka Lab Browsers for macOS

The Shaka Lab Browsers package is a meta-package that installs all major
browsers for a Shaka Lab environment.

This is the macOS package.

## Pre-requisites

 - Get Homebrew: [https://brew.sh/#install](https://brew.sh/#install)

## Installation

```sh
brew tap shaka-project/shaka-lab
brew tap homebrew/cask-versions
brew install --cask shaka-lab-browsers
```

## Updates

```sh
brew update && brew upgrade
```

**NOTE**: This package does not control the update of any browsers.
However, updating packages generally via the above command will update the
browser packages.  Browsers may also auto-update outside of Homebrew packages
if configured to do so.

## Uninstallation

```sh
brew uninstall --cask shaka-lab-browsers
brew autoremove
```

## Specific Browsers Installed

 - Firefox
 - Google Chrome
 - Microsoft Edge
 - Safari Tech Preview (latest macOS versions only)
