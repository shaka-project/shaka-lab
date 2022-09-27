#!/bin/bash

INSTALL_PATH="$(dirname "$0")"

restart_service() {
  local NAME="$1"

  # Load the service if it's not loaded yet.
  local LIST="$(launchctl list | grep "$NAME")"
  if [ -z "$LIST" ]; then
    echo "Loading $NAME"
    launchctl load "$INSTALL_PATH/$NAME.plist"
  fi

  # Stop and start the service.
  echo "Restarting $NAME"
  launchctl stop "$NAME"
  launchctl start "$INSTALL_PATH/$NAME.plist"
}

restart_service shaka-lab-node-update
restart_service shaka-lab-node-service
