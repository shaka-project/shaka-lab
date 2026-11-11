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

import { execFile } from 'node:child_process';

import type { Device, PowerControlConfig } from './config.ts';

export interface PowerResult {
  ok: boolean;
  /** Short human-readable summary. */
  message: string;
  /** Combined stdout and stderr from the command. */
  output: string;
}

export function cycleArgs(control: PowerControlConfig, label: string): string[] {
  const args = ['power', '--label', label, '--cycle'];
  if (control.config) {
    args.push('--config', control.config);
  }
  return args;
}

/**
 * Runs matter-power-control. Commands run one at a time, because chip-tool
 * keeps its state in a single per-user store that isn't safe to share between
 * concurrent processes.
 */
export class PowerController {
  private readonly control: PowerControlConfig;
  private queue: Promise<unknown> = Promise.resolve();

  constructor(control: PowerControlConfig) {
    this.control = control;
  }

  /** Power cycles a device. Never rejects; failures are in the result. */
  cycle(device: Device): Promise<PowerResult> {
    if (!device.power) {
      return Promise.resolve({
        ok: false, message: `${device.name} has no power plug configured`, output: '',
      });
    }
    const args = cycleArgs(this.control, device.power.label);
    const result = this.queue.then(() => this.exec(args));
    this.queue = result;
    return result;
  }

  private exec(args: string[]): Promise<PowerResult> {
    const { command, timeoutSeconds } = this.control;
    return new Promise((resolve) => {
      execFile(command, args, {
        timeout: timeoutSeconds * 1000,
        maxBuffer: 1024 * 1024,
      }, (err, stdout, stderr) => {
        const output = [stdout, stderr].filter((s) => s).join('\n').trim();
        if (!err) {
          resolve({ ok: true, message: 'Done', output });
          return;
        }
        let message: string;
        if (err.killed) {
          message = `Timed out after ${timeoutSeconds} seconds`;
        } else if ((err as NodeJS.ErrnoException).code === 'ENOENT') {
          message = `Command not found: ${command}`;
        } else {
          message = lastLine(stderr) || err.message;
        }
        resolve({ ok: false, message, output });
      });
    });
  }
}

/** The last non-empty line, which for a Python traceback is the error. */
function lastLine(text: string): string {
  const lines = text.split('\n').map((l) => l.trim()).filter((l) => l);
  return lines.at(-1) ?? '';
}
