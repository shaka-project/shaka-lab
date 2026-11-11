# Shaka Lab Access Portal

The Shaka Lab Access Portal package provides a small, device-oriented web
portal for the lab, and is available for **Linux only** (Ubuntu 26.04 or
newer).  It lists devices from a config file, embeds each device's
[TinyPilot][] KVM in the page, and power-cycles devices through Matter power
strips using [matter-power-control][], which is included.

There are no accounts or passwords.  Access is gated by the network: anyone who
can reach the portal's port can use it.  By default, the portal listens only on
`127.0.0.1`, so it is limited to people who can SSH to the machine it runs on.

[TinyPilot]: https://tinypilotkvm.com/
[matter-power-control]: https://github.com/joeyparrish/matter-power-control


## Installation

```sh
curl -L https://shaka-project.github.io/shaka-lab/public.key | \
    sudo tee /etc/apt/trusted.gpg.d/shaka-lab.asc
echo deb https://shaka-project.github.io/shaka-lab/ stable main | \
    sudo tee /etc/apt/sources.list.d/shaka-lab.list
sudo apt update
sudo apt -y install shaka-lab-access-portal
```

This also installs the `chip-tool` snap, which matter-power-control uses to
talk to Matter devices.


## Updates

```sh
sudo apt update && sudo apt -y upgrade
```


## Configuration

The config file is `/etc/shaka-lab-access-portal-config.yaml`.  Every setting
is optional, and the file as installed is a valid config with no devices.  It
documents each setting and has commented examples of each kind of device.

Each device has a `slug`, a `name`, and a `kvm`, a `power`, or both:

- `kvm.url` is the TinyPilot's base URL.  Self-signed certificates are fine.
- `power.label` is a label from matter-power-control's own config file.

The optional `powerControl` section says how to run matter-power-control: the
command, an optional `--config` path, and a timeout.

To use the portal on the LAN without a tunnel, set `listen.host` to `0.0.0.0`
or a LAN address.  Users then need a hostname that resolves to this machine
along with all its subdomains (for example, a wildcard DNS entry), with
`baseDomain` set to match.  Keep in mind that anyone who can reach the port can
then use the KVMs and power-cycle devices.


## Restarting the service after editing the config

```sh
sudo systemctl restart shaka-lab-access-portal
```


## Setting up power control

The portal runs as the `shaka-lab-access-portal` user, whose home is
`/home/shaka-lab-access-portal`.  chip-tool is a snap, and snaps need a home
under `/home` and a systemd user instance, so the package enables lingering for
this user.  Removing the package disables it.

chip-tool keeps its Matter pairing data per user, so set up each power strip as
that user:

```sh
sudo -u shaka-lab-access-portal -H matter-power-control setup \
    --id 1 --ssid "$WIFI_SSID" --password "$WIFI_PASSWORD" --qr photo.jpg
```

Reading a QR code photo requires OpenCV (`python3-opencv`), which is
recommended by this package.  The photo must be readable by the
`shaka-lab-access-portal` user.  See `matter-power-control setup --help` for
details, including how to skip the photo with `--qr-text`.

Then map labels to devices and outlets in `/etc/matter-power-control.json`, as
`"label": "id:outlet"`, and use those labels as `power.label` in the portal
config.  The package installs this file empty, and keeps your edits on upgrade:

```json
{
  "lab-pc": "1:1",
  "test-router": "1:2"
}
```

These pairings are kept if the package is removed, and deleted only if it is
purged.


## Using it over SSH

Forward any free local port to the portal's port on the machine it runs on:

```sh
ssh -L 8080:localhost:8080 gateway
```

Then open <http://kvm.localhost:8080/>.  Use whatever local port you like; the
portal follows the port your browser used.  Other names for your own machine,
like `localhost:8080`, redirect there.

If the portal is reached by an address it can't work from, such as the
machine's IP, it shows a page explaining how to connect.  That page is always
available at `/explain`, and its wording lives in
[src/explain.html](src/explain.html).

Chrome and Firefox resolve every `*.localhost` name to your own machine, so
this needs no DNS or hosts-file changes.  Safari may not; Safari users can add
`127.0.0.1` entries for `kvm.localhost` and each `<slug>.kvm.localhost` to
`/etc/hosts`.


## Tailing logs

```sh
journalctl --no-hostname -u shaka-lab-access-portal --follow
```

Each power cycle request and its outcome are logged.


## Uninstallation

```sh
sudo apt remove -y shaka-lab-access-portal
```

To also delete the Matter pairings and matter-power-control config:

```sh
sudo apt purge -y shaka-lab-access-portal
```


## How it works

TinyPilot doesn't embed or proxy easily:

- It sends `X-Frame-Options: SAMEORIGIN`, so it can't be framed directly.
- It loads everything from root-relative paths (`/js/...`, `/socket.io/`,
  `/stream`), so it can't be proxied under a path prefix.
- Its `session` cookie carries the CSRF token that almost every action needs,
  so each KVM must keep its own cookie.  Cookies ignore ports, so giving each
  KVM its own port wouldn't keep them apart.

So each KVM gets its own hostname.  The portal is `kvm.localhost` and the KVM
for a device with slug `android` is `android.kvm.localhost`.  One Node process
serves both: it routes by hostname and proxies KVM traffic (HTTP and
websockets) to the device, rewriting along the way:

- To the KVM: `Host`, `Origin`, and `Referer` are set to the KVM's own origin,
  so TinyPilot's CSRF and socket.io origin checks pass.
- To the browser: `X-Frame-Options` and any CSP `frame-ancestors` are removed,
  redirects to the KVM's own URL are pointed back at the proxy, and cookies
  lose `Secure` (the browser side is plain HTTP) and any `Domain`.

The portal and KVM hostnames share the registrable domain `kvm.localhost`, so
the browser treats them as the same site and sends TinyPilot's
`SameSite=Strict` cookie inside the iframe.

The "Power cycle" button asks for confirmation, then `POST`s to
`/api/power/<slug>/cycle`, which runs
`matter-power-control power --label <label> --cycle` and waits for it to
finish.  Commands run one at a time, since chip-tool's per-user state isn't
safe to share between concurrent processes.  The endpoint only accepts
requests whose `Origin` is the portal itself, so other websites (and the KVM
pages) can't trigger it.


## Limitations

- **Video must use MJPEG for tunneled users.**  TinyPilot's H.264 mode uses
  WebRTC, which streams media over UDP directly from the device.  That can't go
  through an SSH tunnel or this proxy.  MJPEG goes over plain HTTP and works.
- The KVMs' TLS certificates are not verified.


## Development

Requires Node.js 22.18 or newer from nodejs.org or nvm, which runs the
TypeScript sources directly.  Debian and Ubuntu build Node without TypeScript
support, so the package compiles the sources with `npm run build` instead.

```sh
npm install
cp shaka-lab-access-portal-config.yaml config.yaml   # then edit
npm run dev              # restarts on source changes
npm test                 # unit tests
npm run typecheck
npm run lint
node scripts/smoke.ts android http://kvm.localhost:8080 /tmp/shot.png
```

`scripts/smoke.ts` drives headless Chrome against a running portal and checks
that the embedded KVM renders, its websocket connects, and a CSRF-protected
request succeeds from inside the iframe.  Set `CHROME` if Chrome isn't at
`/usr/bin/google-chrome`.
