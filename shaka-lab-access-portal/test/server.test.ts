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

import assert from 'node:assert/strict';
import http from 'node:http';
import type { AddressInfo } from 'node:net';
import { after, before, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { parseConfig } from '../src/config.ts';
import { createServer } from '../src/server.ts';

const FAKE = fileURLToPath(new URL('./fixtures/fake-power-control.sh', import.meta.url));

const config = parseConfig(`
powerControl:
  command: ${JSON.stringify(FAKE)}
devices:
  - { slug: tv, name: TV, kvm: { url: "https://tv.invalid/" }, power: { label: tv } }
  - { slug: plug, name: Plug, power: { label: plug } }
  - { slug: kvm-only, name: KVM only, kvm: { url: "https://k.invalid/" } }
`);

let server: http.Server;
let port: number;

before(async () => {
  server = createServer(config);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  port = (server.address() as AddressInfo).port;
});
after(() => server.close());

interface Reply { status: number; headers: http.IncomingHttpHeaders; body: string }

function request(method: string, path: string, headers: Record<string, string>): Promise<Reply> {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port, method, path, headers }, (res) => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => resolve({ status: res.statusCode!, headers: res.headers, body }));
    });
    req.on('error', reject);
    req.end();
  });
}

function portal(): Record<string, string> {
  return { host: `kvm.localhost:${port}`, origin: `http://kvm.localhost:${port}` };
}

test('the portal page can power cycle a device', async () => {
  const reply = await request('POST', '/api/power/tv/cycle', portal());
  assert.equal(reply.status, 200);
  const result = JSON.parse(reply.body) as { ok: boolean; output: string };
  assert.equal(result.ok, true);
  assert.match(result.output, /--label tv --cycle/);
});

test('power-only devices work too', async () => {
  const reply = await request('POST', '/api/power/plug/cycle', portal());
  assert.equal(reply.status, 200);
});

test('power requests from anywhere but the portal are refused', async () => {
  const host = `kvm.localhost:${port}`;
  for (const [why, headers] of [
    ['no Origin', { host }],
    ['another site', { host, origin: 'http://evil.example' }],
    ['a KVM page', { host, origin: `http://tv.kvm.localhost:${port}` }],
    ['a different port', { host, origin: 'http://kvm.localhost:1' }],
    ['a loopback host', { host: `localhost:${port}`, origin: `http://localhost:${port}` }],
  ] as const) {
    const reply = await request('POST', '/api/power/tv/cycle', headers);
    assert.equal(reply.status, 403, why);
  }
});

test('power endpoints only accept POST', async () => {
  const reply = await request('GET', '/api/power/tv/cycle', portal());
  assert.equal(reply.status, 405);
});

test('unknown devices, actions, and devices without plugs are 404', async () => {
  for (const path of ['/api/power/nope/cycle', '/api/power/tv/on',
    '/api/power/tv/off', '/api/power/kvm-only/cycle', '/api/nope']) {
    const reply = await request('POST', path, portal());
    assert.equal(reply.status, 404, path);
  }
});

test('pages show power controls only for devices with plugs', async () => {
  const index = await request('GET', '/', { host: `kvm.localhost:${port}` });
  assert.match(index.body, /data-power-slug="tv"/);
  assert.match(index.body, /data-power-slug="plug"/);
  assert.doesNotMatch(index.body, /data-power-slug="kvm-only"/);

  const viewer = await request('GET', '/d/kvm-only', { host: `kvm.localhost:${port}` });
  assert.equal(viewer.status, 200);
  assert.doesNotMatch(viewer.body, /class="power"/);
});

test('loopback hosts redirect to the portal, keeping port and path', async () => {
  const reply = await request('GET', '/d/tv?x=1', { host: `localhost:${port}` });
  assert.equal(reply.status, 302);
  assert.equal(reply.headers.location, `http://kvm.localhost:${port}/d/tv?x=1`);
});
