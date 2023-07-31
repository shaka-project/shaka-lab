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

# Run this script as root if you're not already.
if [[ "$EUID" != "0" ]]; then
  exec sudo "$0"
fi

# Get the user currently logged in on the GUI.
GUI_USER=$(stat -f "%Su" /dev/console)
GUI_HOME=$(eval "echo ~$GUI_USER")

# Stop and unload the services.
sudo -u $GUI_USER launchctl unload $GUI_HOME/Library/LaunchAgents/shaka-lab-node-update.plist
sudo -u $GUI_USER launchctl unload $GUI_HOME/Library/LaunchAgents/shaka-lab-node-service.plist

# Unlink the service definitions.
rm -f $GUI_HOME/Library/LaunchAgents/shaka-lab-node-update.plist
rm -f $GUI_HOME/Library/LaunchAgents/shaka-lab-node-service.plist
