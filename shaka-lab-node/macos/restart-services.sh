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

# Run this script as root via sudo if you're not already root.  Starting the
# app in the GUI user's session takes root, so that this works for any admin,
# not just the GUI user.
if [[ "$EUID" != 0 ]]; then
  exec sudo "$0"
fi

# Don't keep a working directory the GUI user can't read, such as the home
# directory of the admin who ran this.
cd /

/opt/shaka-lab-node/stop-services.sh
sleep 2

echo "Starting services..."
# Start the app as the GUI user, in the GUI user's session.  Plain "open" only
# works from the GUI user's own session.  From anywhere else, such as another
# admin's SSH login, it fails with "Launch failed".
#
# Despite its name, "launchctl asuser" doesn't change users.  It only moves
# the command into the GUI user's session, still running as root.  Then
# "sudo -u" switches to the GUI user, staying in that session.  It has to be
# in this order, because "asuser" needs root.
launchctl asuser "$GUI_UID" sudo -u "#$GUI_UID" open -n /Applications/shaka-lab-node.app
