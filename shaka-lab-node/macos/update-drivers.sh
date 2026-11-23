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

# Update all WebDrivers.  Runs on every node startup, which covers package
# installation and the daily restart.

# Fail on error.
set -e

# Load NVM so we can use our hermetic copy of nodejs.
export NVM_DIR=/opt/shaka-lab-node/nvm
# shellcheck source=/dev/null  # Installed at runtime, not in this repo.
. "$NVM_DIR/nvm.sh"

# Force npm to write its cache here.
export HOME="/opt/shaka-lab-node/work"

# Go to the working directory of shaka-lab-node, which holds the node modules
# and the drivers.  It's the only part of the install this user can write to.
cd /opt/shaka-lab-node/work

# Update all modules to the latest version allowed by package.json.
npm update

# Update all WebDrivers.
./node_modules/.bin/webdriver-installer .
