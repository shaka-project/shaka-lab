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

import js from '@eslint/js';
import { defineConfig } from 'eslint/config';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default defineConfig(
  // linux/ holds packaging, including a staged copy of src/ after a build.
  { ignores: ['node_modules/', 'dist/', 'linux/'] },
  js.configs.recommended,
  tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      globals: globals.node,
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // node:test's test() and friends return promises that the runner
      // tracks itself; they don't need to be awaited.
      '@typescript-eslint/no-floating-promises': ['error', {
        allowForKnownSafeCalls: [{
          from: 'package',
          package: 'node:test',
          name: ['test', 'it', 'describe', 'suite', 'before', 'after'],
        }],
      }],
    },
  },
  {
    // This config file isn't part of the TypeScript project.
    files: ['**/*.mjs'],
    extends: [tseslint.configs.disableTypeChecked],
  },
);
