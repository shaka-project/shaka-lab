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

# Starts the shaka-lab-node services.  The shaka-lab-node app, a login item,
# runs this as the GUI user.  restart-services.sh starts the app, too.
#
# This makes sure there is a Node.js to run log-wrapper.js with, then starts
# log-wrapper.js, which runs start-nodes.sh and starts it again whenever it
# exits.  start-nodes.sh updates NVM and Node.js on every start.
#
# The app only runs this script, so that changes go here, and the signed app
# bundle doesn't have to change.  See automator-app.md.

# Don't keep a working directory the GUI user can't read.
cd /

# log-wrapper.js writes this PID file once it starts, but write it now, so
# that stop-services.sh can stop the retry loop below, too.  The PID stays the
# same, since this script replaces itself with log-wrapper.js.
echo "$$" > /opt/shaka-lab-node/work/shaka-lab-node.pid

# The location of our hermetic NVM installation.
export NVM_DIR=/opt/shaka-lab-node/nvm

# Start from the system's default PATH, the one a login gets, rather than the
# one this inherits.  When Homebrew installs or upgrades the package, install.sh
# runs restart-services.sh, which starts the app with Homebrew's PATH.  That has
# Homebrew's internal git and curl, which only work under brew, so NVM couldn't
# install or update anything.  An admin running restart-services.sh would pass
# along their own PATH, too.
eval "$(env -i /usr/libexec/path_helper -s)"
# Add Homebrew's bin folders, for tools the nodes run, such as docker for the
# Tizen node.  (/usr/local on Intel, /opt/homebrew on Apple Silicon.)
export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

# After a first install, there is no Node.js yet.  Install it, and keep trying
# every 30 seconds until that works (for example, once the network is up).
# Nothing would start the app again until the next login, so this does what
# RestartSec does for the Linux service.  log-wrapper.js isn't running yet, so
# log to its files directly.
if ! /opt/shaka-lab-node/run-node.sh --version &>/dev/null; then
  {
    # shellcheck source=SCRIPTDIR/../node-setup.sh
    . /opt/shaka-lab-node/node-setup.sh
    until setup_node; do
      warn "No usable Node.js yet.  Trying again in 30 seconds."
      sleep 30
    done
  } >>/opt/shaka-lab-node/logs/stdout.log 2>>/opt/shaka-lab-node/logs/stderr.log
fi

exec /opt/shaka-lab-node/run-node.sh \
    /opt/shaka-lab-node/log-wrapper.js \
    /opt/shaka-lab-node/logs/stdout.log \
    /opt/shaka-lab-node/logs/stderr.log \
    /opt/shaka-lab-node/shaka-lab-node.pid \
    /opt/shaka-lab-node/start-nodes.sh
