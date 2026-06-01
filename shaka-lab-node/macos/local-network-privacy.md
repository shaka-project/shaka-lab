# Local Network Privacy on macOS and Shaka Lab Nodes

## Summary

Starting with macOS 15 (Sequoia), macOS gates access to the local network on a
per-application basis (System Settings, Privacy and Security, Local Network).
On a Shaka Lab Mac node this silently blocks the test browser from reaching the
karma server on the lab subnet, even though internet access keeps working.
Selenium runs then fail with `net::ERR_ADDRESS_UNREACHABLE` when the browser
tries to load `https://karma.shakalab.rocks:<port>/`. As of mid 2026 there is
no fix or management control from Apple, and the behavior persists into
macOS 26.

## Symptom

- The browser fails every test with `net::ERR_ADDRESS_UNREACHABLE` when loading
  the karma URL.
- Safari, `curl`, `ping`, and a browser launched by hand from an SSH shell all
  reach the same karma host fine.
- The browser still reaches the public internet, so the test runner can talk to
  GitHub and Google while failing only on the lab subnet.

## Root cause

The blocked connection is a plain IPv4 connect to the karma host on the lab
subnet. A browser netlog shows `os_error: 65` (`EHOSTUNREACH`) on the
`TCP_CONNECT_ATTEMPT`, surfaced to the page as `-109`
(`ERR_ADDRESS_UNREACHABLE`). A packet capture shows no SYN and no ARP leaving
the host for that connect, while an SSH `curl` to the same host does put a SYN
on the wire. In other words, macOS drops the browser's local connection before
it reaches the network, on a per-application basis. This is Local Network
Privacy.

The grant does not stick across browser updates. macOS keys the Local Network
decision to the executable's Mach-O `LC_UUID`, and Chrome stamps a new UUID on
every build, so each stable update looks like a brand new application and the
prompt returns. On an unattended node nobody is present to approve it, so tests
break again on Chrome's release cadence, and duplicate `Google Chrome` entries
pile up in the Local Network settings. This is an Apple-side bug, widely
reported, and still unresolved in macOS 26.

## Why this is hard to solve on a node

Several otherwise obvious fixes are ruled out by hard constraints:

- A GUI session is required. Headless browsers cannot take screenshots, which
  the test suite needs (see commit ab1b542 and the macOS node README), so the
  browser must run as the autologin GUI user. GUI session processes are subject
  to Local Network Privacy.
- A `launchd` agent does not work. The permission prompt is never shown to
  launchd agents, so an agent-based node is permanently blocked. This is why the
  node was moved to an Automator login item (see commit 26bb89b).
- A `launchd` daemon running as root is exempt from Local Network Privacy, but a
  root daemon has no GUI session and therefore cannot run the visible browser
  the suite requires. So the exemption cannot be used for the browser itself.
- There is no MDM key or configuration profile to pre-approve or disable Local
  Network Privacy.
- Chrome cannot be pinned to a fixed version, because the lab must test the
  moving Chrome stable channel.
- The lab cannot necessarily make karma a routed destination. The lab is
  typically a single flat subnet. If the browser host and the karma host share
  a subnet, their traffic is delivered on-link and is treated as local network,
  with no practical way to force it through a router.

## Solution: a loopback proxy

The workable approach keeps the browser in its GUI session, where it stays
gated, but stops it from making the lab-local connection itself. A small proxy
runs on the node and listens on loopback (`127.0.0.1`). The browser is
configured to reach lab hosts through that proxy, so the only address the
browser connects to directly is loopback, which is exempt from Local Network
Privacy. The proxy makes the actual connection to the karma host on the lab
subnet.

To keep the proxy itself out of the privacy gate, run it outside the GUI
session, as a root `launchd` daemon. A proxy needs no GUI, so the root-daemon
limitation that blocks the browser does not apply to it, and root daemons are
exempt from Local Network Privacy. The proxy therefore reaches the lab subnet
regardless of which Chrome build is running, so the fix survives Chrome updates
with no prompts and no manual steps.

The proxy speaks HTTP CONNECT, not SOCKS, on purpose. Karma's control channel is
a WebSocket, and Chrome tunnels `wss` reliably over an HTTP CONNECT proxy but
fails WebSocket over a SOCKS proxy with `ERR_WS_UPGRADE`. The proxy implements
`CONNECT` only, and tunnels to whatever port karma chose (the port is dynamic
per run). That is all that is needed, because the lab serves everything over
HTTPS and `wss`.

### Files in this folder

- `local-network-proxy.js`: the HTTP CONNECT proxy. It is dependency-free and
  binds to `127.0.0.1` only. The listen port is set by the `PROXY_PORT`
  environment variable (default 1080).
- `io.github.shaka-project.shaka-lab-node.local-network-proxy.plist`: the
  LaunchDaemon that runs it. Install it in `/Library/LaunchDaemons` so it loads
  in the system domain as root, which is what grants the Local Network Privacy
  exemption. The path to node uses `$HOMEBREW_PREFIX`, which the package install
  replaces with the real Homebrew prefix; if you load the plist by hand,
  substitute the output of `command -v node` first.

### Wiring the browser

Configure the browser, through the shaka-player lab config, with a proxy
auto-config (PAC) that sends only lab-local destinations to the proxy and leaves
everything else DIRECT. Matching by private address range rather than by
hostname keeps the PAC free of deployment-specific names, and keeping non-lab
traffic DIRECT means the CONNECT-only proxy never sees plain HTTP:

    function FindProxyForURL(url, host) {
      var ip = /^\d+\.\d+\.\d+\.\d+$/.test(host) ? host : dnsResolve(host);
      if (ip && (isInNet(ip, "10.0.0.0", "255.0.0.0") ||
                 isInNet(ip, "172.16.0.0", "255.240.0.0") ||
                 isInNet(ip, "192.168.0.0", "255.255.0.0") ||
                 isInNet(ip, "169.254.0.0", "255.255.0.0"))) {
        return "PROXY 127.0.0.1:1080";
      }
      return "DIRECT";
    }

Inline the PAC as a `--proxy-pac-url=data:application/x-ns-proxy-autoconfig;base64,...`
browser argument so that no file needs to be served.

## Other options considered

- Manual approval through System Settings works for the current Chrome build but
  breaks on the next Chrome update, so it is not viable for an unattended node.
- Auto-accepting the prompt with a scripted click does work, experimentally, at
  least on Sequoia. The Local Network prompt accepts synthetic clicks. But this
  is reactive and fragile: it would need to be scoped to the exact Local Network
  alert so it does not approve unrelated prompts, it depends on an Accessibility
  grant in whatever context launches it, it races with the in-flight test on the
  first run after each Chrome update (that run still fails), and it can break
  silently if Apple changes the dialog wording or layout. The Accessibility
  grant itself is stable, since the helper does not remint its UUID the way
  Chrome does.

## References

- Apple, What is new for enterprise in macOS Sequoia:
  https://support.apple.com/en-jo/121011
- Apple Developer Forums, macOS 15 Sequoia Local Network:
  https://developer.apple.com/forums/thread/764374
- Michael Tsai, Local Network Privacy on Sequoia:
  https://mjtsai.com/blog/2024/10/02/local-network-privacy-on-sequoia/
- macReports, Chrome fills Local Network settings with duplicates and breaks
  network access:
  https://macreports.com/macos-sequoia-bug-chrome-fills-local-network-settings-with-duplicates-and-breaks-network-access-fix/
- Chromium issue 346505950, Chrome local network prompt on macOS:
  https://issues.chromium.org/issues/346505950
- WebSocket over SOCKS versus HTTP proxies (Mozilla bug 1577862):
  https://bugzilla.mozilla.org/show_bug.cgi?id=1577862
- Internal: commit 26bb89b (move to Automator login item for macOS 15), commit
  ab1b542 (GUI session required because headless cannot take screenshots).
