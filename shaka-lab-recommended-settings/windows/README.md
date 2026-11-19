# Shaka Lab Recommended Settings for Windows

The Shaka Lab Recommended Settings package provides recommended OS settings for
a Shaka Lab environment.

This is the Windows package.

## Pre-requisites

 - Get Chocolatey: [https://docs.chocolatey.org/en-us/choco/setup](https://docs.chocolatey.org/en-us/choco/setup)

## Installation

```sh
choco source add -n=shaka-lab -s=https://chocolatey.shakalab.rocks/
choco install shaka-lab-recommended-settings
```

## Updates

```sh
choco upgrade -y shaka-lab-recommended-settings
```

## Installing all updates

Installing or upgrading this package also installs all available Windows and
driver updates.  To install all Chocolatey package and Windows updates at any
other time, run this as an administrator.  It works over SSH:

```sh
shaka-lab-update-os
```

It upgrades all Chocolatey packages, then installs all Windows and driver
updates.  Google Chrome's package can't keep its checksums current, so Chrome
is upgraded without checking them.  Every other package is checked.

If `shaka-lab-node` is running, it's stopped while packages are upgraded, so
that Java and Node.js aren't in use, and started again afterwards.  The Java
and Node.js packages are also told not to restart the computer, which their
installers would otherwise do without asking if their files were in use.

If any Chocolatey package fails to upgrade, the other packages and Windows
updates are still installed, and the command exits with code 1.  It won't
restart the computer, even with `--restart`.

Windows refuses to install updates directly from an SSH session, so the script
runs them as SYSTEM in a scheduled task, waits for them to finish, and prints
the results.

This never restarts the computer, unless a package's own installer does it
without being asked.  If a restart is needed to finish installing updates, it
says so, and exits with code 3010.  To restart the computer when one is
needed, run:

```sh
shaka-lab-update-os --restart
```

## Uninstallation

**NOTE**: This package does not back up your original settings.  Uninstalling
will not restore any settings changed by installation or update of this
package.  It only removes the `shaka-lab-update-os` command and the `klist`
alias from the all-users PowerShell profile.

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
 - Configure PowerShell:
   - Run local scripts and profiles (execution policy `RemoteSigned`)
   - Make `klist` run Windows' `klist`, not the one from the Java JDK, whose
     folder comes first in `PATH`
 - Sync time from time.windows.com, even when joined to a domain
 - Enable Remote Desktop connections
 - Disable firewall
 - Disable all forms of sleep and hibernate
 - Configure VIM:
   - Disable backup files
   - Make Backspace work over SSH
   - Don't clear the screen on exit
 - Configure Windows Update:
   - No updates between midnight at 6pm local
   - Restart without prompting the logged-in user
 - Install all Windows and driver updates now
 - Add the `shaka-lab-update-os` command to install all updates later
