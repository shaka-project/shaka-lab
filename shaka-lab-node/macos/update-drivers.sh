#!/bin/bash

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Update all WebDrivers.  Runs after package installation, on service startup,
# and again nightly.

# Fail on error.
set -e

# Set PATH to include node, npm, and other homebrew executables.
export PATH="$HOMEBREW_PREFIX/bin:$PATH"

# Force npm to write its cache here.
export HOME="/opt/shaka-lab-node"

# Go to the install directory of shaka-lab-node.
cd /opt/shaka-lab-node

# Update all modules to the latest version allowed by package.json.
npm update

# Update all WebDrivers.
./node_modules/.bin/webdriver-installer .
