#!/bin/bash
# Copyright 2026 Google LLC
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

# Sets up the environment (NVM & Node.js), then launches the Selenium nodes
# (via start-nodes.js).
#
# log-wrapper.js runs this as the GUI user, every time it starts the service,
# including after the daily restart.  So NVM and Node.js are installed and
# updated on every service start, as on Linux.  See node-setup.sh.

# The location of our hermetic NVM installation.
export NVM_DIR=/opt/shaka-lab-node/nvm

# shellcheck source=SCRIPTDIR/../node-setup.sh
. /opt/shaka-lab-node/node-setup.sh

setup_node || exit 1

exec node /opt/shaka-lab-node/start-nodes.js
