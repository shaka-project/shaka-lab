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

INSTALL_PATH="/opt/shaka-lab-node"

# Run this script as root if you're not already.
if [[ "$EUID" != "0" ]]; then
  exec sudo "$0"
fi

restart_service() {
  local NAME="$1"

  # Get the user currently logged in on the GUI.
  local GUI_USER=$(stat -f "%Su" /dev/console)
  local GUI_HOME=$(eval "echo ~$GUI_USER")

  # Fail on error
  set -e

  # Link the service into the user's LaunchAgent folder, so that it is
  # automatically loaded on login.
  mkdir -p $GUI_HOME/Library/LaunchAgents
  ln -sf "$INSTALL_PATH/$NAME.plist" $GUI_HOME/Library/LaunchAgents/

  # User-linked service definitions must be owned by that user.
  # The underlying file,
  chown $GUI_USER $GUI_HOME/Library/LaunchAgents/"$NAME.plist"
  # and the link itself.
  chown -h $GUI_USER $GUI_HOME/Library/LaunchAgents/"$NAME.plist"

  # Load the service now if it's not loaded yet.
  local LIST="$(sudo -u $GUI_USER launchctl list | grep "$NAME")"
  if [ -z "$LIST" ]; then
    if sudo -u $GUI_USER launchctl load $GUI_HOME/Library/LaunchAgents/"$NAME.plist"; then
      echo "Loaded $NAME"
    else
      # launchctl load doesn't print error messages, so add one of our own.
      rv=$?
      echo "Loading $NAME failed with rv $rv"
      return $rv
    fi
  fi

  # Stop and start the service.
  echo "Restarting $NAME"
  sudo -u $GUI_USER launchctl stop "$NAME"
  sudo -u $GUI_USER launchctl start "$NAME"
}

# Fail on error
set -e

# Restart both services.
restart_service shaka-lab-node-update
restart_service shaka-lab-node-service
