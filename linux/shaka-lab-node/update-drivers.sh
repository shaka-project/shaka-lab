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

# Update all WebDrivers.  Runs after package installation and again nightly.

if test -z "$NVM_DIR"; then
  # Load NVM so we can use our hermetic copy of nodejs.
  export NVM_DIR=/opt/shaka-lab/nvm
  . "$NVM_DIR/nvm.sh"
fi

cd /opt/shaka-lab/selenium-node

rm -f package-lock.json
npm install

./node_modules/.bin/webdriver-installer .
