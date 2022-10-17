# Selenium Hub

The Selenium Hub package is available for Linux only.

Installation:

```sh
# TODO: download package
sudo dpkg -i shaka-lab-hub*.deb
```

Updates:

```sh
# TODO: Linux updates
```

Configuration:

`/etc/default/shaka-lab-hub` contains one setting: `PORT`.
If you wish to run the Selenium grid hub on a specific port, uncomment and
change the port:

```sh
# The port number to listen on, which defaults to 4444.
#PORT=4444
```

Restarting the service after editing the config:

```sh
sudo systemctl restart shaka-lab-hub
```

Viewing logs:

```sh
journalctl --no-hostname -u shaka-lab-hub
```
