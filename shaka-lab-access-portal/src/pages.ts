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

import { readFileSync } from 'node:fs';
import { hostname } from 'node:os';

import type { Config, Device } from './config.ts';
import { portOf } from './routing.ts';

export function escapeHtml(text: string): string {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

/**
 * The URL of a device's proxied KVM, relative to however the browser reached
 * the portal. Keeping the browser's port means any local tunnel port works.
 */
export function deviceUrl(device: Device, portalHost: string): string {
  return `http://${device.slug}.${portalHost}/`;
}

const STYLE = `
:root {
  color-scheme: light dark;
  --bg: #f6f7f9;
  --panel: #ffffff;
  --text: #1c1f24;
  --muted: #5d6673;
  --border: #d9dde3;
  --accent: #1d5fd1;
  --bar: #1c1f24;
  --bar-text: #e9ecf1;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #14161a;
    --panel: #1c1f24;
    --text: #e9ecf1;
    --muted: #9aa3af;
    --border: #2e333b;
    --accent: #6ea0ff;
    --bar: #0b0c0e;
    --bar-text: #e9ecf1;
  }
}
* { box-sizing: border-box; }
html, body { margin: 0; height: 100%; }
body {
  background: var(--bg);
  color: var(--text);
  font: 15px/1.45 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
}
a { color: var(--accent); }
main { max-width: 760px; margin: 0 auto; padding: 24px 16px; }
h1 { font-size: 20px; margin: 0 0 16px; }
.devices { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
.device {
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 12px 14px;
  display: flex;
  align-items: center;
  column-gap: 16px;
  row-gap: 8px;
  flex-wrap: wrap;
}
.device .info { flex: 1 1 200px; min-width: 0; }
.device .name { font-weight: 600; }
.device .actions { display: flex; align-items: center; gap: 16px; flex-wrap: wrap; }
.device a.open {
  font-size: 13px;
  text-decoration: none;
  border: 1px solid var(--accent);
  border-radius: 4px;
  padding: 3px 10px;
}
.device a.open:hover { background: var(--accent); color: var(--panel); }
.device > .status { flex: 1 0 100%; text-align: right; }
.device > .status:empty { display: none; }
.empty {
  background: var(--panel);
  border: 1px dashed var(--border);
  border-radius: 6px;
  padding: 4px 16px;
}
h2 { font-size: 16px; margin: 24px 0 8px; }
.note { color: var(--muted); font-size: 13px; margin-top: 24px; }
code, pre { font-size: 13px; }
pre {
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 10px 12px;
  overflow-x: auto;
}

/* Viewer */
.viewer { display: flex; flex-direction: column; height: 100vh; height: 100dvh; }
.bar {
  background: var(--bar);
  color: var(--bar-text);
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 0 8px;
  min-height: 36px;
  flex-wrap: wrap;
  font-size: 14px;
}
.bar a { color: var(--bar-text); text-decoration: none; padding: 6px 8px; border-radius: 4px; }
.bar a:hover { background: rgba(255, 255, 255, 0.12); }
.bar a.current { background: rgba(255, 255, 255, 0.18); font-weight: 600; }
.bar .spacer { flex: 1 1 auto; }
.bar .sep { opacity: 0.4; padding: 0 2px; }
iframe { flex: 1 1 auto; width: 100%; border: 0; background: #000; }

/* Power controls */
.power { display: inline-flex; }
.power button {
  font: inherit;
  font-size: 13px;
  color: var(--text);
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 4px;
  padding: 3px 9px;
  cursor: pointer;
}
.power button:hover:not(:disabled) { border-color: var(--accent); }
.power button:disabled { opacity: 0.5; cursor: progress; }
.status { font-size: 13px; color: var(--muted); }
.status.ok { color: #1f8a3b; }
.status.error { color: #c62828; }
@media (prefers-color-scheme: dark) {
  .status.ok { color: #6fdc8c; }
  .status.error { color: #ff8a80; }
}
.bar-power { display: inline-flex; align-items: center; gap: 8px; }
.bar .status { color: var(--bar-text); opacity: 0.75; }
.bar .status.ok { color: #6fdc8c; opacity: 1; }
.bar .status.error { color: #ff8a80; opacity: 1; }
.bar .power button {
  color: var(--bar-text);
  background: transparent;
  border-color: rgba(255, 255, 255, 0.3);
}
.bar .power button:hover:not(:disabled) { background: rgba(255, 255, 255, 0.12); }
`;

// Handles clicks on any power cycle button on the page, after confirming,
// since it interrupts whatever the device is doing.
const POWER_SCRIPT = `
document.addEventListener('click', async (event) => {
  const button = event.target.closest('.power button');
  if (!button) return;
  const group = button.closest('[data-power-slug]');
  const slug = group.dataset.powerSlug;
  const name = group.dataset.powerName;
  if (!confirm('Power cycle ' + name + '?')) return;

  const status = group.querySelector('.status');
  button.disabled = true;
  status.className = 'status';
  status.textContent = 'Power cycling\\u2026';
  status.title = '';
  try {
    const res = await fetch('/api/power/' + slug + '/cycle', { method: 'POST' });
    const result = await res.json();
    status.className = 'status ' + (result.ok ? 'ok' : 'error');
    status.textContent = result.ok ? 'Done' : 'Failed: ' + result.message;
    status.title = result.output || '';
  } catch (err) {
    status.className = 'status error';
    status.textContent = 'Failed: ' + err.message;
  } finally {
    button.disabled = false;
  }
});
`;

/**
 * Attributes marking the element that holds a device's power button and
 * status. The page script finds both inside it.
 */
function powerGroupAttrs(device: Device): string {
  return `data-power-slug="${device.slug}" data-power-name="${escapeHtml(device.name)}"`;
}

function powerButtons(): string {
  return `<span class="power"><button type="button">Power cycle</button></span>`;
}

const STATUS = '<span class="status" role="status" aria-live="polite"></span>';

function page(title: string, body: string, script = ''): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>
<style>${STYLE}</style>
</head>
<body>
${body}
${script ? `<script type="module">${script}</script>` : ''}
</body>
</html>
`;
}

export function indexPage(config: Config): string {
  const items = config.devices.map((device) => {
    const open = device.kvm ?
        `<a class="open" href="/d/${device.slug}">Open KVM</a>` : '';
    const group = device.power ? ' ' + powerGroupAttrs(device) : '';
    return `<li class="device"${group}>
  <div class="info">
    <div class="name">${escapeHtml(device.name)}</div>
  </div>
  <div class="actions">
    ${device.power ? powerButtons() : ''}
    ${open}
  </div>
  ${device.power ? STATUS : ''}
</li>`;
  });
  if (items.length === 0) {
    return page('Lab Devices', `<main>
<h1>Lab devices</h1>
${noDevicesHint(config)}
</main>`);
  }
  return page('Lab Devices', `<main>
<h1>Lab devices</h1>
<ul class="devices">
${items.join('\n')}
</ul>
</main>`, POWER_SCRIPT);
}

function noDevicesHint(config: Config): string {
  const file = config.path ?
      `<code>${escapeHtml(config.path)}</code>` : 'the config file';
  return `<div class="empty">
<p>No devices are set up yet.</p>
<p>To add some, edit ${file} and restart the portal. The <code>devices</code>
section of the default config file has commented examples.</p>
</div>`;
}

export function viewerPage(config: Config, device: Device, portalHost: string): string {
  const src = deviceUrl(device, portalHost);
  const switcher = config.devices.filter((d) => d.kvm).map((d) => {
    const cls = d.slug === device.slug ? ' class="current" aria-current="page"' : '';
    return `<a href="/d/${d.slug}"${cls}>${escapeHtml(d.name)}</a>`;
  });
  return page(device.name, `<div class="viewer">
<nav class="bar">
  <a href="/">Devices</a>
  <span class="sep">|</span>
  ${switcher.join('\n  ')}
  <span class="spacer"></span>
  ${device.power ? `<span class="bar-power" ${powerGroupAttrs(device)}>
    ${STATUS}
    ${powerButtons()}
  </span>` : ''}
</nav>
<iframe src="${escapeHtml(src)}" title="${escapeHtml(device.name)} KVM"
    allow="fullscreen; clipboard-read; clipboard-write; autoplay"></iframe>
</div>`, device.power ? POWER_SCRIPT : '');
}

/** The portal's URL, keeping whatever port the browser used. */
export function portalUrl(config: Config, hostHeader: string, path = '/'): string {
  const port = portOf(hostHeader);
  return `http://${config.baseDomain}${port ? ':' + port : ''}${path}`;
}

const EXPLAIN_TEMPLATE = new URL('./explain.html', import.meta.url);

/**
 * Explains how to reach the portal by name. The wording lives in
 * explain.html, which is re-read on every request to make editing easy.
 */
export function explainPage(config: Config, hostHeader: string): string {
  const firstKvm = config.devices.find((d) => d.kvm);
  const values: Record<string, string> = {
    host: hostHeader || '(unknown)',
    portalUrl: portalUrl(config, hostHeader),
    baseDomain: config.baseDomain,
    exampleKvm: `${firstKvm?.slug ?? 'device'}.${config.baseDomain}`,
    serverName: hostname(),
    port: String(config.listen.port),
  };
  const template = readFileSync(EXPLAIN_TEMPLATE, 'utf8')
      .replace(/^\s*<!--[\s\S]*?-->\s*/, '');
  const body = template.replace(/\{\{(\w+)\}\}/g,
      (match, key: string) => key in values ? escapeHtml(values[key]!) : match);
  return page('Portal Address', body);
}

export function notFoundPage(): string {
  return page('Not Found', `<main>
<h1>Not found</h1>
<p><a href="/">Back to devices</a></p>
</main>`);
}
