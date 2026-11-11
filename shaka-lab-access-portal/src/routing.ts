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

import type { Config, Device } from './config.ts';

export type Route =
  | { kind: 'portal' }
  | { kind: 'device'; device: Device }
  /** Some other name for this machine; redirect to the portal. */
  | { kind: 'loopback' }
  /** An address the portal can't work from, such as a LAN IP. */
  | { kind: 'unknown'; hostname: string };

function splitHost(hostHeader: string): [string, string] {
  const host = hostHeader.trim().toLowerCase();
  if (host.startsWith('[')) {
    const end = host.indexOf(']');
    if (end === -1) return [host, ''];
    const rest = host.slice(end + 1);
    return [host.slice(0, end + 1), rest.startsWith(':') ? rest.slice(1) : ''];
  }
  const colon = host.lastIndexOf(':');
  return colon === -1 ? [host, ''] : [host.slice(0, colon), host.slice(colon + 1)];
}

/** Strip an optional port (keeping IPv6 brackets) from a Host header value. */
export function hostnameOf(hostHeader: string): string {
  return splitHost(hostHeader)[0];
}

/** The port from a Host header value, or '' if there is none. */
export function portOf(hostHeader: string): string {
  return splitHost(hostHeader)[1];
}

export function isLoopback(hostname: string): boolean {
  return hostname === 'localhost' ||
      hostname.endsWith('.localhost') ||
      hostname === '[::1]' ||
      /^127\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(hostname);
}

/**
 * True if a request's Origin header is the portal itself, as reached by this
 * request. This rejects other websites and the (same-site) KVM pages, so that
 * only the portal's own pages can trigger actions like power control.
 */
export function isPortalOrigin(
    config: Config, originHeader: string | undefined,
    hostHeader: string | undefined): boolean {
  if (!originHeader || !hostHeader) return false;
  let origin: URL;
  try {
    origin = new URL(originHeader);
  } catch {
    return false;
  }
  return origin.protocol === 'http:' &&
      origin.hostname === config.baseDomain &&
      origin.host === hostHeader.trim().toLowerCase();
}

/**
 * Decide what a request is for, based only on the hostname. The port is
 * ignored so that users can pick any local port for their SSH tunnel.
 */
export function route(config: Config, hostHeader: string | undefined): Route {
  const hostname = hostnameOf(hostHeader ?? '');
  if (hostname === config.baseDomain) {
    return { kind: 'portal' };
  }
  const suffix = '.' + config.baseDomain;
  if (hostname.endsWith(suffix)) {
    const slug = hostname.slice(0, -suffix.length);
    const device = config.devices.find((d) => d.slug === slug && d.kvm);
    if (device) {
      return { kind: 'device', device };
    }
  }
  if (isLoopback(hostname)) {
    return { kind: 'loopback' };
  }
  return { kind: 'unknown', hostname };
}
