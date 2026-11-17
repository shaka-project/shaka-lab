# Shaka Lab Recommended Settings for Linux

The Shaka Lab Recommended Settings package provides recommended OS settings for
a Shaka Lab environment.

This is the Linux package.

## Installation

```sh
curl -L https://shaka-project.github.io/shaka-lab/public.key | \
    sudo tee /etc/apt/trusted.gpg.d/shaka-lab.asc
echo deb https://shaka-project.github.io/shaka-lab/ stable main | \
    sudo tee /etc/apt/sources.list.d/shaka-lab.list
sudo apt update
sudo apt install -y shaka-lab-recommended-settings
```

## Updates

To install all package and OS updates, run this as an admin:

```sh
shaka-lab-update-os
```

It runs `apt update` and `apt full-upgrade`.  `apt` shows what it will
install, upgrade, and remove, and asks before going ahead.  It also asks what
to do about any config file you changed that an update replaces.

This never restarts the computer.  If a restart is needed to finish installing
updates, it says so, and exits with code 100.  To restart the computer when
one is needed, run:

```sh
shaka-lab-update-os --restart
```

**NOTE**: This package makes updates restart any services they affect,
without asking.  On the gateway, that can include Samba, DNS, and DHCP.

## Uninstallation

```sh
sudo apt remove -y shaka-lab-recommended-settings
```

## Specific Settings and Dependencies

Dependencies installed with this package:
 - aptitude (console apt frontend)
 - arping (network debugging tool)
 - curl (download tool)
 - debconf-utils (debian configuration tools)
 - dialog (console configuration dialogs for packages)
 - gpg (signature and key tool)
 - net-tools (more network debugging tools)
 - openssh-server (SSH server)
 - plocate (file search tool)
 - smartmontools (disk monitoring tools)
 - tcpdump (network debugging/sniffing tool)
 - vim (text editor)
 - wget (download tool)

Settings configured automatically by this package:
 - Configure SSH server:
   - Disable root login
   - Enable port-forwarding
 - Configure SSH client (OpenSSH 10.1 and later only):
   - Don't warn about missing post-quantum key exchange when connecting to lab
     hosts.  Older clients never warn, and don't understand the setting.
 - Disable prompting for service restarts, always restart affected services
 - Configure additional apt repositories to install major browsers
 - Prefer Mozilla's apt repo for Firefox over Ubuntu's snap package
 - Add the `shaka-lab-update-os` command to install all updates
