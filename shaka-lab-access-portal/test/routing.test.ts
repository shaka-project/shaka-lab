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
import { test } from 'node:test';

import { parseConfig } from '../src/config.ts';
import { hostnameOf, isPortalOrigin, portOf, route } from '../src/routing.ts';

const config = parseConfig(`
devices:
  - { slug: android, name: Android, kvm: { url: "https://android.lan/" } }
  - { slug: plug-only, name: Plug, power: { label: p } }
`);

test('hostnameOf strips ports', () => {
  assert.equal(hostnameOf('kvm.localhost:8080'), 'kvm.localhost');
  assert.equal(hostnameOf('KVM.localhost'), 'kvm.localhost');
  assert.equal(hostnameOf('[::1]:8080'), '[::1]');
});

test('portOf extracts ports', () => {
  assert.equal(portOf('kvm.localhost:8080'), '8080');
  assert.equal(portOf('kvm.localhost'), '');
  assert.equal(portOf('[::1]:9123'), '9123');
  assert.equal(portOf('[::1]'), '');
});

test('the base domain is the portal, on any port', () => {
  assert.deepEqual(route(config, 'kvm.localhost:8080'), { kind: 'portal' });
  assert.deepEqual(route(config, 'kvm.localhost:12345'), { kind: 'portal' });
  assert.deepEqual(route(config, 'kvm.localhost'), { kind: 'portal' });
});

test('a device subdomain routes to that device, on any port', () => {
  for (const host of ['android.kvm.localhost:8080', 'android.kvm.localhost:9999']) {
    const r = route(config, host);
    assert.equal(r.kind, 'device');
    assert.equal(r.kind === 'device' && r.device.slug, 'android');
  }
});

test('other loopback names are redirected to the portal', () => {
  for (const host of ['localhost:8080', '127.0.0.1:8080', '127.1.2.3', '[::1]:8080',
    'nope.kvm.localhost', 'plug-only.kvm.localhost', 'a.android.kvm.localhost',
    'evilkvm.localhost']) {
    assert.equal(route(config, host).kind, 'loopback', host);
  }
});

test('isPortalOrigin accepts only the portal origin on the same port', () => {
  const host = 'kvm.localhost:8080';
  assert.equal(isPortalOrigin(config, 'http://kvm.localhost:8080', host), true);
  assert.equal(isPortalOrigin(config, undefined, host), false);
  assert.equal(isPortalOrigin(config, 'null', host), false);
  assert.equal(isPortalOrigin(config, 'http://android.kvm.localhost:8080', host), false);
  assert.equal(isPortalOrigin(config, 'http://kvm.localhost:9999', host), false);
  assert.equal(isPortalOrigin(config, 'https://kvm.localhost:8080', host), false);
  assert.equal(isPortalOrigin(config, 'http://kvm.localhost:8080', undefined), false);
});

test('non-loopback hosts are unknown', () => {
  for (const host of ['10.0.0.5:8080', 'gateway.lan', 'localhost.evil.com',
    '127.0.0.1.evil.com', undefined]) {
    assert.equal(route(config, host).kind, 'unknown', String(host));
  }
});
