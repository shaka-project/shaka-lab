#!/bin/bash

INSTALL_PATH="$(dirname "$0")"

restart_service() {
  local NAME="$1"

  # Link the service into the user's LaunchAgent folder, so that it is
  # automatically loaded on login.
  ln -sf "$INSTALL_PATH/$NAME.plist" ~/Library/LaunchAgents/

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
