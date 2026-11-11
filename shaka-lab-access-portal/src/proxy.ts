/* Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import http from 'node:http';
import https from 'node:https';
import type { Duplex } from 'node:stream';

import type { Device } from './config.ts';

// Headers that describe a single hop and must not be forwarded.
const HOP_BY_HOP = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'proxy-connection',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
]);

/**
 * The browser talks to us over plain HTTP at e.g.
 * http://android.kvm.localhost:8080, while the KVM lives at
 * https://shaka-test-android-control. These rewrites make each side see what
 * it expects.
 */
export interface Origins {
  /** e.g. "http://android.kvm.localhost:8080" */
  client: string;
  /** e.g. "https://shaka-test-android-control" */
  upstream: string;
}

export function rewriteRequestHeaders(
    headers: http.IncomingHttpHeaders, origins: Origins,
    upgrade: boolean): http.OutgoingHttpHeaders {
  const out: http.OutgoingHttpHeaders = {};
  for (const [name, value] of Object.entries(headers)) {
    if (value === undefined) continue;
    if (HOP_BY_HOP.has(name) && !(upgrade && (name === 'connection' || name === 'upgrade'))) {
      continue;
    }
    out[name] = value;
  }

  out.host = new URL(origins.upstream).host;

  // TinyPilot's CSRF protection (Flask-WTF, strict Referer checks over HTTPS)
  // and socket.io's Origin check both expect to see the KVM's own origin.
  if (typeof out.origin === 'string') {
    out.origin = origins.upstream;
  }
  if (typeof out.referer === 'string') {
    out.referer = swapOrigin(out.referer, origins.client, origins.upstream);
  }
  return out;
}

export function rewriteResponseHeaders(
    headers: http.IncomingHttpHeaders, origins: Origins): http.OutgoingHttpHeaders {
  const out: http.OutgoingHttpHeaders = {};
  for (const [name, value] of Object.entries(headers)) {
    if (value === undefined || HOP_BY_HOP.has(name)) continue;
    out[name] = value;
  }

  // Allow the KVM UI to be framed by the portal.
  delete out['x-frame-options'];
  if (typeof out['content-security-policy'] === 'string') {
    const csp = stripFrameAncestors(out['content-security-policy']);
    if (csp) {
      out['content-security-policy'] = csp;
    } else {
      delete out['content-security-policy'];
    }
  }

  if (typeof out.location === 'string') {
    out.location = swapOrigin(out.location, origins.upstream, origins.client);
  }

  const cookies = out['set-cookie'];
  if (Array.isArray(cookies)) {
    const secure = origins.client.startsWith('https:');
    out['set-cookie'] = cookies.map((c) => rewriteSetCookie(c, secure));
  }
  return out;
}

/** Replace a leading origin in a URL string, leaving anything else alone. */
export function swapOrigin(url: string, from: string, to: string): string {
  if (url === from || url.startsWith(from + '/') ||
      url.startsWith(from + '?') || url.startsWith(from + '#')) {
    return to + url.slice(from.length);
  }
  return url;
}

export function stripFrameAncestors(csp: string): string {
  return csp.split(';')
      .map((d) => d.trim())
      .filter((d) => d && !/^frame-ancestors(\s|$)/i.test(d))
      .join('; ');
}

/**
 * Cookies must stay host-only (so each KVM keeps its own "session" cookie),
 * and can't be Secure when the browser is talking plain HTTP to us.
 */
export function rewriteSetCookie(cookie: string, clientIsSecure: boolean): string {
  const [nameValue, ...attrs] = cookie.split(';');
  const kept = attrs.map((a) => a.trim()).filter((a) => {
    const key = a.split('=')[0]!.trim().toLowerCase();
    if (key === 'domain') return false;
    if (key === 'secure' && !clientIsSecure) return false;
    return a !== '';
  });
  return [nameValue!.trim(), ...kept].join('; ');
}

export class KvmProxy {
  readonly device: Device;
  readonly upstream: URL;
  private readonly agent: http.Agent;

  constructor(device: Device) {
    if (!device.kvm) throw new Error(`device ${device.slug} has no kvm`);
    this.device = device;
    this.upstream = device.kvm.url;
    const isHttps = this.upstream.protocol === 'https:';
    // KVMs on the lab LAN use self-signed certs, so don't verify them.
    this.agent = isHttps ?
        new https.Agent({ keepAlive: true, rejectUnauthorized: false }) :
        new http.Agent({ keepAlive: true });
  }

  private request(options: https.RequestOptions): http.ClientRequest {
    const transport = this.upstream.protocol === 'https:' ? https : http;
    return transport.request({
      protocol: this.upstream.protocol,
      hostname: this.upstream.hostname,
      port: this.upstream.port || undefined,
      ...options,
    });
  }

  private origins(req: http.IncomingMessage): Origins {
    return {
      client: `http://${req.headers.host}`,
      upstream: this.upstream.origin,
    };
  }

  handleRequest(req: http.IncomingMessage, res: http.ServerResponse): void {
    const origins = this.origins(req);
    const upstreamReq = this.request({
      method: req.method,
      path: req.url,
      headers: rewriteRequestHeaders(req.headers, origins, false),
      agent: this.agent,
    });

    upstreamReq.on('response', (upstreamRes) => {
      res.writeHead(upstreamRes.statusCode ?? 502,
          upstreamRes.statusMessage,
          rewriteResponseHeaders(upstreamRes.headers, origins));
      upstreamRes.pipe(res);
      // If the browser goes away mid-stream (e.g. MJPEG), stop reading.
      res.on('close', () => upstreamRes.destroy());
    });

    upstreamReq.on('error', (err) => {
      if (!res.headersSent) {
        res.writeHead(502, { 'content-type': 'text/plain; charset=utf-8' });
        res.end(`Unable to reach ${this.device.name} (${this.upstream.host}): ${err.message}\n`);
      } else {
        res.destroy();
      }
    });

    req.pipe(upstreamReq);
  }

  handleUpgrade(req: http.IncomingMessage, socket: Duplex, head: Buffer): void {
    const origins = this.origins(req);
    const upstreamReq = this.request({
      method: req.method,
      path: req.url,
      headers: rewriteRequestHeaders(req.headers, origins, true),
      rejectUnauthorized: false,
    });

    socket.on('error', () => upstreamReq.destroy());

    upstreamReq.on('upgrade', (upstreamRes, upstreamSocket, upstreamHead) => {
      const lines = [`HTTP/1.1 101 ${upstreamRes.statusMessage ?? 'Switching Protocols'}`];
      for (let i = 0; i < upstreamRes.rawHeaders.length; i += 2) {
        lines.push(`${upstreamRes.rawHeaders[i]}: ${upstreamRes.rawHeaders[i + 1]}`);
      }
      socket.write(lines.join('\r\n') + '\r\n\r\n');
      if (upstreamHead.length) socket.write(upstreamHead);
      if (head.length) upstreamSocket.write(head);

      upstreamSocket.on('error', () => socket.destroy());
      socket.on('close', () => upstreamSocket.destroy());
      upstreamSocket.on('close', () => socket.destroy());
      upstreamSocket.pipe(socket);
      socket.pipe(upstreamSocket);
    });

    // Upstream declined the upgrade: relay its answer and hang up.
    upstreamReq.on('response', (upstreamRes) => {
      const lines = [`HTTP/1.1 ${upstreamRes.statusCode} ${upstreamRes.statusMessage}`];
      const headers = rewriteResponseHeaders(upstreamRes.headers, origins);
      for (const [name, value] of Object.entries(headers)) {
        for (const v of [value].flat()) lines.push(`${name}: ${v}`);
      }
      lines.push('connection: close');
      socket.write(lines.join('\r\n') + '\r\n\r\n');
      upstreamRes.pipe(socket);
    });

    upstreamReq.on('error', () => {
      socket.end('HTTP/1.1 502 Bad Gateway\r\nconnection: close\r\n\r\n');
    });

    upstreamReq.end();
  }
}
