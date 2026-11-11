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
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import type { Device, PowerControlConfig } from '../src/config.ts';
import { PowerController, cycleArgs } from '../src/power.ts';

const FAKE = fileURLToPath(new URL('./fixtures/fake-power-control.sh', import.meta.url));

function control(overrides: Partial<PowerControlConfig> = {}): PowerControlConfig {
  return { command: FAKE, timeoutSeconds: 10, ...overrides };
}

function device(label: string): Device {
  return { slug: label, name: label, power: { label } };
}

test('cycleArgs builds the matter-power-control command line', () => {
  assert.deepEqual(cycleArgs(control(), 'tv'),
      ['power', '--label', 'tv', '--cycle']);
  assert.deepEqual(cycleArgs(control({ config: '/etc/mpc.json' }), 'tv'),
      ['power', '--label', 'tv', '--cycle', '--config', '/etc/mpc.json']);
});

test('a successful command reports ok with its output', async () => {
  const result = await new PowerController(control()).cycle(device('tv'));
  assert.equal(result.ok, true);
  assert.equal(result.message, 'Done');
  assert.match(result.output, /args: power --label tv --cycle/);
});

test('a failing command reports the last line of stderr', async () => {
  const result = await new PowerController(control()).cycle(device('fail'));
  assert.equal(result.ok, false);
  assert.equal(result.message, 'RuntimeError: Failed to power off.');
  assert.match(result.output, /Traceback/);
});

test('a missing command is reported clearly', async () => {
  const result = await new PowerController(control({ command: '/nonexistent/mpc' }))
      .cycle(device('tv'));
  assert.equal(result.ok, false);
  assert.equal(result.message, 'Command not found: /nonexistent/mpc');
});

test('a slow command times out', async () => {
  const result = await new PowerController(control({ timeoutSeconds: 0.1 }))
      .cycle(device('slow'));
  assert.equal(result.ok, false);
  assert.match(result.message, /Timed out/);
});

test('a device without a plug is rejected without running anything', async () => {
  const result = await new PowerController(control())
      .cycle({ slug: 'k', name: 'KVM only' });
  assert.equal(result.ok, false);
  assert.match(result.message, /no power plug/);
});

const tmp = mkdtempSync(join(tmpdir(), 'portal-power-test-'));
after(() => rmSync(tmp, { recursive: true, force: true }));

test('commands run one at a time, even after a failure', async () => {
  const log = join(tmp, 'log');
  process.env.FAKE_POWER_LOG = log;
  try {
    const power = new PowerController(control());
    const results = await Promise.all([
      power.cycle(device('slow')),
      power.cycle(device('fail')),
      power.cycle(device('slow')),
    ]);
    assert.deepEqual(results.map((r) => r.ok), [true, false, true]);
    // "fail" exits before logging its end, but must still start after the
    // first command ends and finish before the third starts.
    assert.deepEqual(readFileSync(log, 'utf8').trim().split('\n'),
        ['start slow', 'end slow', 'start fail', 'start slow', 'end slow']);
  } finally {
    delete process.env.FAKE_POWER_LOG;
  }
});
