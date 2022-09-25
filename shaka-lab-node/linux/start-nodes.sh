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

# Sets up the environment (NVM & Xvfb), updates drivers, then launches the
# Selenium nodes (via start-nodes.js).

# Load NVM so we can use our hermetic copy of nodejs.
export NVM_DIR=/opt/shaka-lab/nvm
. "$NVM_DIR/nvm.sh"

# Launch Selenium nodes in a headless X session.
xvfb-run -a node /opt/shaka-lab/selenium-node/start-nodes.js

# TODO: Can this be configured to wait for a login and run the nodes in the
# main X session instead?  That way, test runs can be seen.
