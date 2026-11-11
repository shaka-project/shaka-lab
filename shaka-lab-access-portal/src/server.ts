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
import { parseArgs } from 'node:util';

import { loadConfig, type Config } from './config.ts';
import { explainPage, indexPage, notFoundPage, portalUrl, viewerPage } from './pages.ts';
import { PowerController } from './power.ts';
import { KvmProxy } from './proxy.ts';
import { isPortalOrigin, route } from './routing.ts';

function send(res: http.ServerResponse, status: number, html: string): void {
  res.writeHead(status, {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(html);
}

function sendJson(res: http.ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(JSON.stringify(body));
}

export function createServer(config: Config): http.Server {
  const proxies = new Map<string, KvmProxy>();
  for (const device of config.devices) {
    if (device.kvm) proxies.set(device.slug, new KvmProxy(device));
  }
  const power = new PowerController(config.powerControl);

  function handlePowerCycle(
      req: http.IncomingMessage, res: http.ServerResponse,
      slug: string, onPortalHost: boolean): void {
    if (req.method !== 'POST') {
      res.writeHead(405, { allow: 'POST' });
      res.end();
      return;
    }
    if (!onPortalHost || !isPortalOrigin(config, req.headers.origin, req.headers.host)) {
      sendJson(res, 403, { ok: false, message: 'Forbidden', output: '' });
      return;
    }
    const device = config.devices.find((d) => d.slug === slug && d.power);
    if (!device) {
      sendJson(res, 404, { ok: false, message: 'Not found', output: '' });
      return;
    }
    // Drain any request body; we don't use it.
    req.resume();
    const who = req.socket.remoteAddress;
    console.log(`power cycle ${device.slug} requested by ${who}`);
    power.cycle(device).then((result) => {
      console.log(`power cycle ${device.slug}: ${result.ok ? 'ok' : 'FAILED: ' + result.message}`);
      if (!result.ok && result.output) console.log(result.output);
      sendJson(res, result.ok ? 200 : 502, result);
    }).catch((err: unknown) => {
      console.error(`power cycle ${device.slug}: internal error`, err);
      if (!res.headersSent) {
        sendJson(res, 500, { ok: false, message: 'Internal error', output: '' });
      }
    });
  }

  const server = http.createServer((req, res) => {
    const target = route(config, req.headers.host);

    if (target.kind === 'device') {
      proxies.get(target.device.slug)!.handleRequest(req, res);
      return;
    }

    const hostHeader = req.headers.host ?? '';
    const url = new URL(req.url ?? '/', 'http://portal');
    const path = url.pathname;

    const powerMatch = /^\/api\/power\/([^/]+)\/cycle$/.exec(path);
    if (powerMatch) {
      handlePowerCycle(req, res, powerMatch[1]!, target.kind === 'portal');
      return;
    }
    if (path.startsWith('/api/')) {
      sendJson(res, 404, { ok: false, message: 'Not found', output: '' });
      return;
    }

    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.writeHead(405, { allow: 'GET, HEAD' });
      res.end();
      return;
    }

    // Available from any address, to make it easy to review the wording.
    if (path === '/explain') {
      send(res, 200, explainPage(config, hostHeader));
      return;
    }

    if (target.kind === 'loopback') {
      res.writeHead(302, {
        location: portalUrl(config, hostHeader, path + url.search),
        'cache-control': 'no-store',
      });
      res.end();
      return;
    }

    if (target.kind === 'unknown') {
      send(res, 421, explainPage(config, hostHeader));
      return;
    }

    if (path === '/') {
      send(res, 200, indexPage(config));
      return;
    }
    if (path === '/favicon.ico') {
      res.writeHead(204);
      res.end();
      return;
    }
    const match = /^\/d\/([^/]+)\/?$/.exec(path);
    const device = match && config.devices.find((d) => d.slug === match[1] && d.kvm);
    if (device) {
      send(res, 200, viewerPage(config, device, req.headers.host!));
      return;
    }
    send(res, 404, notFoundPage());
  });

  server.on('upgrade', (req, socket, head) => {
    const target = route(config, req.headers.host);
    if (target.kind === 'device') {
      proxies.get(target.device.slug)!.handleUpgrade(req, socket, head);
    } else {
      socket.destroy();
    }
  });

  return server;
}

function main(): void {
  const { values } = parseArgs({
    options: {
      config: { type: 'string', short: 'c', default: 'config.yaml' },
    },
  });
  const config = loadConfig(values.config);
  const server = createServer(config);
  server.listen(config.listen.port, config.listen.host, () => {
    console.log(`Portal listening on ${config.listen.host}:${config.listen.port}`);
    console.log(`Open http://${config.baseDomain}:${config.listen.port}/ ` +
        '(or whatever local port you tunnel to)');
  });
}

if (import.meta.main) {
  main();
}
