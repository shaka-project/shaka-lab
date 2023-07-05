# Shaka Lab Browsers for Windows

The Shaka Lab Browsers package is a meta-package that installs all major
browsers for a Shaka Lab environment.

This is the Windows package.

## Pre-requisites

 - Get Chocolatey: [https://docs.chocolatey.org/en-us/choco/setup](https://docs.chocolatey.org/en-us/choco/setup)

## Installation

```sh
choco source add -n=shaka-lab -s=https://shaka-lab-chocolatey-dot-shaka-player-demo.appspot.com/
choco install shaka-lab-browsers
```

## Updates

**NOTE**: This package does not control the update of any browsers.
On Windows, browsers update themselves independently of any package.

## Uninstallation

```sh
choco uninstall -y shaka-lab-browsers firefox googlechrome
```

## Specific Browsers Installed

 - Firefox
 - Google Chrome
