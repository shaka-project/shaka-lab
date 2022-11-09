# Shaka Lab Hub

The Shaka Lab Hub package provides a Selenium grid hub, and is available for
**Linux only**.


## Installation

TODO: Package distribution

## Updates

TODO: Package distribution

## Configuration

`/etc/default/shaka-lab-hub` contains two settings: `PORT` and `HOST`.
If you wish to run the Selenium grid hub on a specific port, uncomment and
change the `PORT` setting:

```sh
# The port number to listen on, which defaults to 4444.
#PORT=4444
```

If you wish to listen on a specific IP or hostname, uncomment and change the
`HOST` setting:

```sh
# The IP or hostname to listen on, which defaults to 0.0.0.0 (all IPs).
#HOST=0.0.0.0
```

## Restarting the service after editing the config

```sh
sudo systemctl restart shaka-lab-hub
```

## Tailing logs

```sh
journalctl --no-hostname -u shaka-lab-hub --follow
```

## Uninstallation

```sh
sudo apt remove -y shaka-lab-hub
```
