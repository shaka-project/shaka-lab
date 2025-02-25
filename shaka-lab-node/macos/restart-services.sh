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

# Fail on error
set -e

# Get the user ID currently logged in on the GUI.
GUI_UID=$(stat -f "%Du" /dev/console)

# Run this script as the GUI user via sudo if you're not already the GUI user.
if [[ "$EUID" != "$GUI_UID" ]]; then
  exec sudo -u "#$GUI_UID" "$0"
fi

/opt/shaka-lab-node/stop-services.sh
sleep 2

echo "Starting services..."
open -n /Applications/shaka-lab-node.app
