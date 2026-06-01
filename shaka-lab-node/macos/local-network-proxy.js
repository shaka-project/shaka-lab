#!/usr/bin/env node
'use strict';

// Minimal loopback HTTP CONNECT proxy for Shaka Lab macOS nodes.
//
// Why this exists: macOS 15+ Local Network Privacy blocks the GUI test browser
// from reaching lab hosts (such as the karma server) on the local subnet, and
// the per-app grant does not survive Chrome updates. See
// local-network-privacy.md for the full background.
//
// The browser is pointed at this proxy on loopback (127.0.0.1), which is exempt
// from Local Network Privacy. This process, run as a root launchd daemon, is
// itself exempt, so it can reach lab hosts regardless of the browser's grant or
// version. It binds to loopback only and must never be exposed to the network.
//
// HTTP CONNECT, not SOCKS: Chrome tunnels WebSocket (wss) reliably over an HTTP
// CONNECT proxy, but WebSocket over a SOCKS proxy fails with ERR_WS_UPGRADE.
// Karma's control channel is a WebSocket, so SOCKS is not usable here.
//
// CONNECT only: the lab is HTTPS (and wss), so every proxied request is a TLS
// tunnel. Plain-HTTP forwarding is intentionally not implemented. Pair this with
// a PAC that sends only lab-local hosts here and leaves everything else DIRECT.
//
// Configure the listen port with the PROXY_PORT environment variable
// (default 1080).

const net = require('net');

const HOST = '127.0.0.1';
const PORT = parseInt(process.env.PROXY_PORT || '1080', 10);

const log = (...args) => console.log(new Date().toISOString(), ...args);

const server = net.createServer((client) => {
  client.on('error', () => client.destroy());

  let buf = Buffer.alloc(0);

  const onHeaders = (chunk) => {
    buf = Buffer.concat([buf, chunk]);
    const sep = buf.indexOf('\r\n\r\n');
    if (sep === -1) {
      if (buf.length > 16384) client.destroy(); // header unreasonably large
      return;
    }
    client.removeListener('data', onHeaders);

    const requestLine = buf.subarray(0, buf.indexOf('\r\n')).toString('ascii');
    const leftover = buf.subarray(sep + 4); // normally empty for CONNECT
    const m = /^CONNECT\s+(\S+):(\d+)\s+HTTP\/1\.[01]$/i.exec(requestLine);
    if (!m) {
      client.end('HTTP/1.1 405 Method Not Allowed\r\n\r\n');
      return;
    }
    const host = m[1];
    const port = parseInt(m[2], 10);

    client.pause(); // hold client bytes until the tunnel is established
    const upstream = net.connect(port, host);
    let connected = false;

    client.on('close', () => upstream.destroy());
    upstream.on('close', () => client.destroy());
    upstream.on('error', (e) => {
      if (connected) return client.destroy(); // mid-stream: just tear down
      log('upstream', `${host}:${port}`, 'failed:', e.code || e.message);
      client.end('HTTP/1.1 502 Bad Gateway\r\n\r\n');
    });
    upstream.on('connect', () => {
      connected = true;
      client.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      if (leftover.length) upstream.write(leftover);
      client.pipe(upstream); // resumes the paused client
      upstream.pipe(client);
    });
  };

  client.on('data', onHeaders);
});

server.on('error', (e) => { log('server error:', e.message); process.exit(1); });
server.listen(PORT, HOST, () => log(`HTTP CONNECT proxy listening on ${HOST}:${PORT}`));
