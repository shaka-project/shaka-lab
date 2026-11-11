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

import {
  rewriteRequestHeaders,
  rewriteResponseHeaders,
  rewriteSetCookie,
  stripFrameAncestors,
  swapOrigin,
} from '../src/proxy.ts';

const origins = {
  client: 'http://android.kvm.localhost:8080',
  upstream: 'https://shaka-test-android-control',
};

test('request headers point at the upstream origin', () => {
  const out = rewriteRequestHeaders({
    host: 'android.kvm.localhost:8080',
    origin: 'http://android.kvm.localhost:8080',
    referer: 'http://android.kvm.localhost:8080/some/page?x=1',
    cookie: 'session=abc',
    connection: 'keep-alive',
    'x-csrftoken': 'tok',
  }, origins, false);
  assert.equal(out.host, 'shaka-test-android-control');
  assert.equal(out.origin, 'https://shaka-test-android-control');
  assert.equal(out.referer, 'https://shaka-test-android-control/some/page?x=1');
  assert.equal(out.cookie, 'session=abc');
  assert.equal(out['x-csrftoken'], 'tok');
  assert.equal(out.connection, undefined);
});

test('upgrade requests keep connection and upgrade headers', () => {
  const out = rewriteRequestHeaders({
    host: 'android.kvm.localhost:8080',
    connection: 'Upgrade',
    upgrade: 'websocket',
  }, origins, true);
  assert.equal(out.connection, 'Upgrade');
  assert.equal(out.upgrade, 'websocket');
});

test('response headers allow framing and fix cookies and redirects', () => {
  const out = rewriteResponseHeaders({
    'x-frame-options': 'SAMEORIGIN',
    'content-security-policy': "default-src 'self'; frame-ancestors 'self'",
    location: 'https://shaka-test-android-control/login',
    'set-cookie': ['session=abc; Secure; HttpOnly; Path=/; SameSite=Strict'],
    'transfer-encoding': 'chunked',
    'content-type': 'text/html',
  }, origins);
  assert.equal(out['x-frame-options'], undefined);
  assert.equal(out['content-security-policy'], "default-src 'self'");
  assert.equal(out.location, 'http://android.kvm.localhost:8080/login');
  assert.deepEqual(out['set-cookie'], ['session=abc; HttpOnly; Path=/; SameSite=Strict']);
  assert.equal(out['transfer-encoding'], undefined);
  assert.equal(out['content-type'], 'text/html');
});

test('swapOrigin only replaces a whole leading origin', () => {
  assert.equal(swapOrigin('https://a', 'https://a', 'http://b'), 'http://b');
  assert.equal(swapOrigin('https://a/x', 'https://a', 'http://b'), 'http://b/x');
  assert.equal(swapOrigin('https://a.evil/x', 'https://a', 'http://b'), 'https://a.evil/x');
  assert.equal(swapOrigin('/relative', 'https://a', 'http://b'), '/relative');
});

test('stripFrameAncestors removes only that directive', () => {
  assert.equal(stripFrameAncestors("frame-ancestors 'none'"), '');
  assert.equal(stripFrameAncestors("default-src 'self';frame-ancestors x; img-src *"),
      "default-src 'self'; img-src *");
});

test('rewriteSetCookie drops Domain, and Secure unless the client is HTTPS', () => {
  assert.equal(rewriteSetCookie('a=1; Domain=lan; Secure; Path=/', false), 'a=1; Path=/');
  assert.equal(rewriteSetCookie('a=1; Domain=lan; Secure; Path=/', true), 'a=1; Secure; Path=/');
});
