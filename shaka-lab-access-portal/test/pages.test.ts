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
import { explainPage, indexPage } from '../src/pages.ts';

test('the explain page leaves out its template comment', () => {
  const html = explainPage(parseConfig(''), '10.0.0.5:8080');
  assert.match(html, /Open the portal by name/);
  assert.match(html, /<code>10\.0\.0\.5:8080<\/code>/);
  assert.doesNotMatch(html, /Copyright|Licensed under|Placeholders/);
});

test('with no devices, the index page explains how to add some', () => {
  const html = indexPage({ ...parseConfig(''), path: '/etc/portal/config.yaml' });
  assert.match(html, /No devices are set up yet/);
  assert.match(html, /<code>\/etc\/portal\/config\.yaml<\/code>/);
  assert.doesNotMatch(html, /class="devices"/);
});

test('with devices, there is no hint', () => {
  const html = indexPage(parseConfig('devices: [{ slug: a, name: A, power: { label: a } }]'));
  assert.doesNotMatch(html, /No devices are set up yet/);
  assert.match(html, /class="devices"/);
});
