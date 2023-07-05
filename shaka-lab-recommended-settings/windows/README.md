# Shaka Lab Recommended Settings for Windows

The Shaka Lab Recommended Settings package provides recommended OS settings for
a Shaka Lab environment.

This is the Windows package.

## Pre-requisites

 - Get Chocolatey: [https://docs.chocolatey.org/en-us/choco/setup](https://docs.chocolatey.org/en-us/choco/setup)

## Installation

```sh
choco source add -n=shaka-lab -s=https://shaka-lab-chocolatey-dot-shaka-player-demo.appspot.com/
choco install shaka-lab-recommended-settings
```

## Updates

```sh
choco upgrade -y shaka-lab-recommended-settings
```

## Uninstallation

**NOTE**: This package does not back up your original settings.  Uninstalling
will not restore any settings changed by installation or update of this
package.

```sh
choco uninstall -y shaka-lab-recommended-settings
```

## Specific Settings and Dependencies

Dependencies installed with this package:
 - vim (text editor)

Settings configured automatically by this package:
 - Install and start Microsoft SSH server
 - Configure SSH server:
   - Use PowerShell as the login shell
   - Disable SSH keys shared across all admin accounts
 - Enable Remote Desktop connections
 - Disable firewall
 - Disable all forms of sleep and hibernate
 - Configure VIM:
   - Disable backup files
 - Configure Windows Update:
   - No updates between midnight at 6pm local
   - Restart without prompting the logged-in user
 - Install all Windows and driver updates now
