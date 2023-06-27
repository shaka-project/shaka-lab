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

INSTALL_PATH="$(dirname "$0")"

restart_service() {
  local NAME="$1"

  # Link the service into the user's LaunchAgent folder, so that it is
  # automatically loaded on login.
  ln -sf "$INSTALL_PATH/plists/$NAME.plist" ~/Library/LaunchAgents/

  # Load the service now if it's not loaded yet.
  local LIST="$(launchctl list | grep "$NAME")"
  if [ -z "$LIST" ]; then
    echo "Loading $NAME"
    launchctl load ~/Library/LaunchAgents/"$NAME.plist"
  fi

  # Stop and start the service.
  echo "Restarting $NAME"
  launchctl stop "$NAME"
  launchctl start "$NAME"
}

# Restart both services.
restart_service shaka-lab-node-update
restart_service shaka-lab-node-service

# Configure log rotation.  10MB files (10240), compress with gzip (flag Z).
# This needs to happen here.  It can't be done inside the Homebrew formula
# because of sandboxing.  We must write files in a global location.
if [ ! -f /etc/newsyslog.d/shaka-lab-node.conf ]; then
  echo "Configuring service log rotation (using sudo)"
  sudo tee /etc/newsyslog.d/shaka-lab-node.conf >/dev/null <<EOF
# path                                        mode  count  size  when  flags pid_file
$(brew --prefix)/var/log/shaka-lab-node.*.log 644   10     10240 *     Z     $(brew --prefix)/var/run/shaka-lab-node.pid
EOF
fi
