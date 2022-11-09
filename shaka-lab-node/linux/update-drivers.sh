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

# If run as root (from cron or package postinstall script), the script
# re-launches itself as the non-root user that owns the folder.
if [[ "$EUID" == 0 ]]; then
  exec /bin/su shaka-lab-node -s /bin/bash -c "$0"
  # NOTE: exec replaces the current running process, and doesn't return.
fi

# Load NVM so we can use our hermetic copy of nodejs.
export NVM_DIR=/opt/shaka-lab/nvm
. "$NVM_DIR/nvm.sh"

# Go to the install directory of shaka-lab-node.
cd /opt/shaka-lab/shaka-lab-node

# Update all modules.
rm -f package-lock.json
npm install

# Update all WebDrivers.
./node_modules/.bin/webdriver-installer .
