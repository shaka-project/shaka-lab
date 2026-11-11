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
import { resolve } from 'node:path';
import { parse } from 'yaml';

export interface KvmConfig {
  /** Base URL of the KVM's web UI, e.g. https://shaka-test-android-control/ */
  url: URL;
}

export interface PowerConfig {
  /** Label understood by `matter-power-control power --label`. */
  label: string;
}

export interface Device {
  /** Short DNS-safe name, used as the device's subdomain. */
  slug: string;
  /** Human-friendly display name. */
  name: string;
  kvm?: KvmConfig;
  power?: PowerConfig;
}

export interface PowerControlConfig {
  /** The matter-power-control executable (a name on PATH, or a path). */
  command: string;
  /** Passed as --config if set; otherwise the tool uses its own default. */
  config?: string;
  /** Give up on a single power command after this long. */
  timeoutSeconds: number;
}

export interface Config {
  listen: { host: string; port: number };
  /** Portal is served at this hostname, devices at <slug>.<baseDomain>. */
  baseDomain: string;
  powerControl: PowerControlConfig;
  devices: Device[];
  /** Where the config was loaded from, if from a file. */
  path?: string;
}

const SLUG_RE = /^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/;

class ConfigError extends Error {}

function fail(message: string): never {
  throw new ConfigError(message);
}

function asObject(value: unknown, where: string): Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${where} must be a mapping`);
  }
  return value as Record<string, unknown>;
}

function asString(value: unknown, where: string): string {
  if (typeof value !== 'string' || value === '') {
    fail(`${where} must be a non-empty string`);
  }
  return value;
}

function parseKvm(raw: unknown, where: string): KvmConfig {
  const obj = asObject(raw, where);
  const urlText = asString(obj.url, `${where}.url`);
  let url: URL;
  try {
    url = new URL(urlText);
  } catch {
    fail(`${where}.url is not a valid URL: ${urlText}`);
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') {
    fail(`${where}.url must be http or https: ${urlText}`);
  }
  if (url.pathname !== '/' || url.search || url.hash) {
    // TinyPilot uses root-relative paths everywhere, so it must live at /.
    fail(`${where}.url must not have a path, query, or fragment: ${urlText}`);
  }
  return { url };
}

function parsePower(raw: unknown, where: string): PowerConfig {
  const obj = asObject(raw, where);
  return { label: asString(obj.label, `${where}.label`) };
}

function parseDevice(raw: unknown, index: number): Device {
  const where = `devices[${index}]`;
  const obj = asObject(raw, where);
  const slug = asString(obj.slug, `${where}.slug`);
  if (!SLUG_RE.test(slug)) {
    fail(`${where}.slug must be lowercase letters, digits, and hyphens: ${slug}`);
  }
  const device: Device = {
    slug,
    name: asString(obj.name, `${where}.name`),
  };
  if (obj.kvm != null) {
    device.kvm = parseKvm(obj.kvm, `${where}.kvm`);
  }
  if (obj.power != null) {
    device.power = parsePower(obj.power, `${where}.power`);
  }
  if (!device.kvm && !device.power) {
    fail(`${where} (${slug}) must have a kvm, a power, or both`);
  }
  return device;
}

/**
 * Parses the YAML config. Empty values are treated as absent, so an empty
 * file (or one with only comments) is a valid config with no devices.
 */
export function parseConfig(text: string): Config {
  const root = asObject(parse(text) ?? {}, 'config');

  const listenRaw = root.listen == null ? {} : asObject(root.listen, 'listen');
  const host = listenRaw.host == null ?
      '127.0.0.1' : asString(listenRaw.host, 'listen.host');
  const port = listenRaw.port == null ? 8080 : listenRaw.port;
  if (typeof port !== 'number' || !Number.isInteger(port) ||
      port < 1 || port > 65535) {
    fail('listen.port must be an integer from 1 to 65535');
  }

  const baseDomain = (root.baseDomain == null ?
      'kvm.localhost' : asString(root.baseDomain, 'baseDomain')).toLowerCase();

  const powerControl = parsePowerControl(root.powerControl);

  const devicesRaw = root.devices ?? [];
  if (!Array.isArray(devicesRaw)) {
    fail('devices must be a list');
  }
  const devices = devicesRaw.map(parseDevice);

  const seen = new Set<string>();
  for (const device of devices) {
    if (seen.has(device.slug)) {
      fail(`duplicate device slug: ${device.slug}`);
    }
    seen.add(device.slug);
  }

  return { listen: { host, port }, baseDomain, powerControl, devices };
}

/** Loads a config file, remembering its absolute path for display. */
export function loadConfig(path: string): Config {
  return { ...parseConfig(readFileSync(path, 'utf8')), path: resolve(path) };
}

function parsePowerControl(raw: unknown): PowerControlConfig {
  const obj = raw == null ? {} : asObject(raw, 'powerControl');
  const control: PowerControlConfig = {
    command: obj.command == null ?
        'matter-power-control' : asString(obj.command, 'powerControl.command'),
    timeoutSeconds: 60,
  };
  if (obj.config != null) {
    control.config = asString(obj.config, 'powerControl.config');
  }
  if (obj.timeoutSeconds != null) {
    if (typeof obj.timeoutSeconds !== 'number' || !(obj.timeoutSeconds > 0)) {
      fail('powerControl.timeoutSeconds must be a positive number');
    }
    control.timeoutSeconds = obj.timeoutSeconds;
  }
  return control;
}

