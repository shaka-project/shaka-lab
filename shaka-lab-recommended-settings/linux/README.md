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

```sh
sudo apt update && sudo apt -y upgrade
```

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
 - Prefer Mozila PPA for Firefox over Ubuntu snap package
