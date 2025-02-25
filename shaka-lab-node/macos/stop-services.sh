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

PID_FILE=/opt/shaka-lab-node/shaka-lab-node.pid

if [[ -e "$PID_FILE" ]]; then
  # The ID of the log-wrapper process, which is also the process group ID for
  # all processes beneath that.
  PROCESS_GROUP_ID=$(cat $PID_FILE)
  # The parent process of that group, the Automator app.
  AUTOMATOR_PROCESS_ID=$(ps -o ppid= -p $PROCESS_GROUP_ID || true)

  # Kill the group, as well as the Automator app, ignoring errors.
  # The negative number is interpreted by kill as a group ID instead of a
  # process ID, so it will kill everything in the group.
  echo "Stopping services..."
  kill -s TERM -- -$PROCESS_GROUP_ID $AUTOMATOR_PROCESS_ID 2>/dev/null || true

  rm -f "$PID_FILE"
fi
