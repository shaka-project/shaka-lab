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
brew trust shaka-project/shaka-lab
brew install shaka-lab-recommended-settings
```

## Updates

```sh
brew update && brew upgrade shaka-lab-recommended-settings
```

Updating applies all the settings again, which restarts the screen sharing
agent and disconnects anyone using VNC.

## Installing all updates

To install all Homebrew package and macOS updates, run this as an admin.  It
works over SSH:

```sh
shaka-lab-update-os
```

It runs `brew update` and `brew upgrade`, then installs macOS updates with
`softwareupdate`.  Apps that update themselves, such as Chrome and Edge, are
left to do that.  Firefox only updates itself while it's running, and on lab
machines it only runs under Selenium, which turns updates off, so it's always
upgraded with Homebrew.  `brew upgrade` shows what it will upgrade, and asks before going
ahead.  At that question, Ctrl+C, Esc, and Ctrl+D all mean no.  Anywhere
else, Ctrl+C stops the whole command.

After the Homebrew upgrades, it takes Firefox, Chrome and Edge out of
quarantine, in case Homebrew upgraded any of them.  A quarantined browser can
show a dialog that blocks tests until someone answers it.

If any Homebrew package fails to upgrade, or you tell `brew upgrade` not to go
ahead, macOS updates are still installed, and the command exits with code 1.
It won't restart the computer, even with `--restart`, because a failed upgrade
can leave a package unable to start.
A pinned package, or one that depends on a pinned package, can't be upgraded,
so avoid pinning packages on lab machines.

Homebrew runs as the user logged in on the GUI, whichever admin runs this.  So
Homebrew packages that need admin rights ask for the GUI user's password, and
the prompt says so.  On Apple silicon, macOS updates also ask for the GUI
user's password, as the owner of the disk.

This never restarts the computer.  Installing a macOS update that needs a
restart always restarts the computer right away, so those updates are only
downloaded.  If a restart is needed, it says so, and exits with code 100.

To also install the macOS updates that need a restart, and restart the computer
when they're installed, run:

```sh
shaka-lab-update-os --restart
```

## Uninstallation

```sh
brew uninstall shaka-lab-recommended-settings
brew autoremove
```

**NOTE**: This package does not back up your original OS settings.
Uninstalling the package will not reset any modified settings to their previous
or default values.

## Specific Settings and Dependencies

Dependencies installed with this package:
 - None

Settings configured automatically by this package:
 - Remote access:
   - Enable SSH for admins (lab users are given access by
     [`shaka-lab-gateway-client`](../../shaka-lab-gateway-client/macos/README.md#readme))
   - Enable VNC
 - Configure SSH client (OpenSSH 10.1 and later only):
   - Don't warn about missing post-quantum key exchange when connecting to lab
     hosts.  Older clients never warn, and don't understand the setting.
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
   - Enable time sync with Apple servers
   - Enable autologin for the current user (necessary for shaka-lab-node to run
     typical GUI browsers).  This asks for the user's password on the first
     install only.  To store a new password, delete `/etc/kcpassword` and
     reinstall.
 - Add the `shaka-lab-update-os` command to install all updates
