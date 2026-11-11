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

// Browser smoke test: open a device in the portal's viewer with headless
// Chrome and check that the embedded KVM UI actually works through the proxy.
//
// Usage: node scripts/smoke.ts <slug> [portal-origin] [screenshot.png]
// e.g.:  node scripts/smoke.ts android http://kvm.localhost:8080 /tmp/a.png

import puppeteer from 'puppeteer-core';

const slug = process.argv[2] ?? 'android';
const portal = process.argv[3] ?? 'http://kvm.localhost:8080';
const screenshot = process.argv[4];
const chrome = process.env.CHROME ?? '/usr/bin/google-chrome';

const browser = await puppeteer.launch({ executablePath: chrome, headless: true });
let failed = false;
function check(ok: boolean, what: string, detail = ''): void {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}${detail ? `  (${detail})` : ''}`);
  if (!ok) failed = true;
}

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1400, height: 900 });

  const problems: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') problems.push(`console: ${msg.text()}`);
  });
  page.on('requestfailed', (req) => {
    problems.push(`request failed: ${req.url()} ${req.failure()?.errorText}`);
  });
  page.on('response', (res) => {
    if (res.status() >= 400) problems.push(`HTTP ${res.status()}: ${res.url()}`);
  });

  const sockets: string[] = [];
  const cdp = await page.createCDPSession();
  await cdp.send('Network.enable');
  cdp.on('Network.webSocketHandshakeResponseReceived', (e) => {
    sockets.push(`${e.response.status}`);
  });

  await page.goto(`${portal}/d/${slug}`, { waitUntil: 'load' });
  // Let socket.io connect and the video start.
  await new Promise((r) => setTimeout(r, 6000));

  const frame = page.frames().find((f) => f.url().includes(`//${slug}.`));
  check(!!frame, 'KVM iframe navigated', frame?.url());
  if (frame) {
    const title = await frame.evaluate(() => document.title);
    check(title.length > 0, 'KVM page rendered', `title: ${title}`);

    // A CSRF-protected no-op. It only succeeds if the KVM's session cookie
    // made it into the iframe and the Origin/Referer rewrites satisfy Flask.
    const status = await frame.evaluate(async () => {
      const meta = document.querySelector("meta[name='csrf-token']");
      const res = await fetch('/api/logout', {
        method: 'POST',
        headers: { 'X-CSRFToken': meta?.getAttribute('content') ?? '' },
      });
      return res.status;
    });
    check(status === 200, 'CSRF-protected POST from iframe', `HTTP ${status}`);
  }

  check(sockets.includes('101'), 'websocket upgraded', sockets.join(',') || 'none');

  if (screenshot) {
    await page.screenshot({ path: screenshot });
    console.log(`screenshot: ${screenshot}`);
  }
  for (const p of problems) console.log(`note  ${p}`);
} finally {
  await browser.close();
}
process.exit(failed ? 1 : 0);
