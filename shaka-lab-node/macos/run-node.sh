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

# Runs NVM's default Node.js with the given arguments.
#
# NVM has no fixed path to the default Node.js, since the path includes the
# version.  This gives the local-network proxy's LaunchDaemon (as root) and
# launch.sh (as the GUI user) a path that doesn't change when Node.js updates.
#
# This never installs or updates anything.  start-nodes.sh does that.

# The location of our hermetic NVM installation.  Tests can override it.
export NVM_DIR="${NVM_DIR:-/opt/shaka-lab-node/nvm}"

if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  echo "NVM is not installed in $NVM_DIR!" 1>&2
  exit 1
fi

# shellcheck source=/dev/null  # Installed at runtime, not in this repo.
. "$NVM_DIR/nvm.sh" --no-use

node_path=$(nvm which default 2>/dev/null)
if [[ ! -x "$node_path" ]]; then
  echo "Node.js is not installed in $NVM_DIR!" 1>&2
  exit 1
fi

exec "$node_path" "$@"
