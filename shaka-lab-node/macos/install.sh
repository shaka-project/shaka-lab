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

# Installs shaka-lab-node on macOS.  Homebrew runs this as root from the
# Cask's preflight_steps.
#
# Usage: install.sh <path to shaka-lab source> <Homebrew prefix>

# Fail on error
set -e

source_root="$1"
homebrew_prefix="$2"

# The destination folder of most shaka-lab-node files.
destination="/opt/shaka-lab-node"

proxy_plist="/Library/LaunchDaemons/io.github.shaka-project.shaka-lab-node.local-network-proxy.plist"

# Create the destination directory.
mkdir -p "$destination"

# Main shaka-lab-node files.  This includes uninstall.sh, which the Cask runs
# from here on uninstall.
install -m 644 "$source_root/LICENSE.txt" "$destination"
install -m 644 "$source_root/selenium-jar/selenium-server-standalone-3.141.59.jar" "$destination"
install -m 644 "$source_root/shaka-lab-node/node-templates.yaml" "$destination"
install -m 644 "$source_root/shaka-lab-node/package.json" "$destination"
install -m 644 "$source_root/shaka-lab-node/start-nodes.js" "$destination"
for path in "$source_root"/shaka-lab-node/macos/*; do
  if [[ "$path" != *.app ]]; then
    install -m 644 "$path" "$destination"
  fi
done
# Mark the shell scripts as executable.
for path in "$source_root"/shaka-lab-node/macos/*.sh; do
  install -m 755 "$path" "$destination"
done

# Don't overwrite the config file if it already exists!
# This file will be left in tact during uninstall.
if [[ ! -e /etc/shaka-lab-node-config.yaml ]]; then
  install -m 644 "$source_root/shaka-lab-node/shaka-lab-node-config.yaml" /etc/
fi

# Certain files need hard-coded paths to node.js, which is installed under
# a variable Homebrew prefix.  So replace the string "$HOMEBREW_PREFIX"
# with the current prefix.
sed -i '' -e "s|\\\$HOMEBREW_PREFIX|$homebrew_prefix|g" "$destination/update-drivers.sh"

# Service logs go here, so make sure the folder exists:
mkdir -p "$destination/logs"

# Install and load the loopback proxy LaunchDaemon.  It works around macOS
# Local Network Privacy, which otherwise blocks the test browser from
# reaching lab hosts.  It must be a root daemon for the privacy exemption.
# See local-network-privacy.md.  Its plist references "$HOMEBREW_PREFIX" for
# the path to node, which we replace with the real prefix here.
install -m 644 "$source_root/shaka-lab-node/macos/io.github.shaka-project.shaka-lab-node.local-network-proxy.plist" "$proxy_plist"
sed -i '' -e "s|\\\$HOMEBREW_PREFIX|$homebrew_prefix|g" "$proxy_plist"
# Reload it.  Tolerate "not loaded" on a first install.
launchctl bootout system "$proxy_plist" 2>/dev/null || true
launchctl bootstrap system "$proxy_plist"

# Get the user currently logged in on the GUI.
gui_user=$(stat -f "%Su" /dev/console)

# Make the destination directory owned by the logged-in GUI user.
# Make sure the service account can write to all the necessary locations in
# the installation to do updates and logging:
chown -R "$gui_user" "$destination"

# Symlink the log rotation config file into its required location.
ln -sf "$destination/shaka-lab-node-logrotate.conf" /etc/newsyslog.d/

# Copy the .app bundle to /Applications/
cp -R "$source_root/shaka-lab-node/macos/shaka-lab-node.app" /Applications/

# Remove the obsolete update-drivers app that older versions installed.
# Driver updates now happen on node startup (including the daily restart),
# so the app is no longer used.  This cleans it up on upgrade.
rm -rf /Applications/shaka-lab-node-update-drivers.app

# Set shaka-lab-node to start on login.  This runs as the installing user, as
# it did when the Cask ran it directly.
sudo -u "$SUDO_USER" osascript -e \
    'tell application "System Events" to make login item at end with properties {path:"/Applications/shaka-lab-node.app", hidden:false}'

# Now start/restart the services.
echo "Restarting services..."
"$destination/restart-services.sh"
echo "Done!"
