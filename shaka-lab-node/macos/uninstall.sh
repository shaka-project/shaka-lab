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

# Uninstalls shaka-lab-node on macOS.  Homebrew runs this as root from the
# Cask's uninstall_preflight_steps.  install.sh puts it in /opt/shaka-lab-node.

# Fail on error
set -e

destination="/opt/shaka-lab-node"
proxy_plist="/Library/LaunchDaemons/io.github.shaka-project.shaka-lab-node.local-network-proxy.plist"

echo "Stopping services..."
"$destination/stop-services.sh"
echo "Done!"

# Unload the loopback proxy LaunchDaemon before removing it.  Tolerate it
# already being unloaded.
launchctl bootout system "$proxy_plist" 2>/dev/null || true

# Remove the main installation, except NVM and Node.js, the working directory,
# and the service logs.  Upgrades uninstall the old version first.  The new
# version keeps using NVM, Node.js, and the node modules and WebDrivers in the
# working directory, so they shouldn't be downloaded again, and keeping the
# logs keeps their history.  Only "brew uninstall --zap" removes them.
find "$destination" -mindepth 1 -maxdepth 1 \
    ! -name nvm ! -name work ! -name logs -exec rm -rf {} +
# Remove the folder too, if there was nothing left in it.
rmdir "$destination" 2>/dev/null || true

# Remove the symlinks and everything else.  This leaves the loopback proxy's
# log in /var/log/shaka-lab-node, for the same reason, and the login item,
# which install.sh adds back without duplicating it.  Only
# "brew uninstall --zap" removes them.
rm -rf \
    /etc/newsyslog.d/shaka-lab-node-logrotate.conf \
    /Applications/shaka-lab-node.app \
    /Applications/shaka-lab-node-update-drivers.app \
    "$proxy_plist"
