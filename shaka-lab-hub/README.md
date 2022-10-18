# Selenium Hub

The Selenium Hub package is available for Linux only.

Installation:

```sh
curl -L https://shaka-project.github.io/shaka-lab/public.key | \
    sudo tee /etc/apt/trusted.gpg.d/shaka-lab.asc
echo deb https://shaka-project.github.io/shaka-lab/ stable main | \
    sudo tee /etc/apt/sources.list.d/shaka-lab.list
sudo apt update
sudo apt install shaka-lab-hub
```

Updates:

```sh
sudo apt update && sudo apt upgrade
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
