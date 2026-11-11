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
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import { parseConfig } from '../src/config.ts';

const EXAMPLE = readFileSync('shaka-lab-access-portal-config.yaml', 'utf8');

test('the example config parses as an empty config with defaults', () => {
  const config = parseConfig(EXAMPLE);
  assert.equal(config.baseDomain, 'kvm.localhost');
  assert.deepEqual(config.listen, { host: '127.0.0.1', port: 8080 });
  assert.equal(config.powerControl.command, 'matter-power-control');
  assert.deepEqual(config.devices, []);
});

test('the example devices are valid once uncommented', () => {
  // Uncomment everything from "# devices:" on. Comments inside the examples
  // are double-hashed, so they stay comments.
  const start = EXAMPLE.indexOf('# devices:');
  assert.notEqual(start, -1);
  const devices = EXAMPLE.slice(start).replace(/^# ?/gm, '');
  const config = parseConfig(devices);
  assert.deepEqual(config.devices.map((d) => [d.slug, !!d.kvm, !!d.power]), [
    ['lab-pc', true, true],
    ['media-player', true, false],
    ['test-router', false, true],
  ]);
});

for (const [why, yaml] of [
  ['an empty file', ''],
  ['only comments', '# nothing here\n'],
  ['empty sections', 'listen:\npowerControl:\ndevices:\n'],
  ['an empty device list', 'devices: []'],
] as const) {
  test(`accepts ${why}`, () => {
    const config = parseConfig(yaml);
    assert.deepEqual(config.devices, []);
    assert.equal(config.listen.port, 8080);
  });
}

test('listen and baseDomain have defaults', () => {
  const config = parseConfig(`
devices:
  - slug: a
    name: A
    kvm: { url: "https://a.lan/" }
`);
  assert.equal(config.baseDomain, 'kvm.localhost');
  assert.deepEqual(config.listen, { host: '127.0.0.1', port: 8080 });
});

test('power-only and kvm-only devices are allowed', () => {
  const config = parseConfig(`
devices:
  - { slug: k, name: K, kvm: { url: "https://k.lan" } }
  - { slug: p, name: P, power: { label: p } }
`);
  assert.ok(config.devices[0]!.kvm && !config.devices[0]!.power);
  assert.ok(config.devices[1]!.power && !config.devices[1]!.kvm);
});

for (const [why, yaml, message] of [
  ['devices that is not a list', 'devices: { slug: a }', /devices must be a list/],
  ['a non-mapping config', '- just a list', /config must be a mapping/],
  ['neither kvm nor power', 'devices: [{ slug: a, name: A }]', /kvm, a power, or both/],
  ['bad slug', 'devices: [{ slug: A_B, name: A, power: { label: x } }]', /slug must be/],
  ['duplicate slug',
    'devices: [{ slug: a, name: A, power: { label: x } }, { slug: a, name: B, power: { label: y } }]',
    /duplicate/],
  ['kvm url with a path', 'devices: [{ slug: a, name: A, kvm: { url: "https://a/x" } }]',
    /must not have a path/],
  ['non-http kvm url', 'devices: [{ slug: a, name: A, kvm: { url: "ftp://a/" } }]',
    /http or https/],
  ['bad port', 'listen: { port: 99999 }\ndevices: [{ slug: a, name: A, power: { label: x } }]',
    /listen.port/],
] as const) {
  test(`rejects ${why}`, () => {
    assert.throws(() => parseConfig(yaml), message);
  });
}
