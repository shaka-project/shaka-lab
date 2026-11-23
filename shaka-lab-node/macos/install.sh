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
# Usage: install.sh <path to shaka-lab source>

# Fail on error
set -e

source_root="$1"

# The destination folder of most shaka-lab-node files.
destination="/opt/shaka-lab-node"

# The service's working directory, for node modules, WebDrivers, npm's cache,
# and PID files.  Along with the service logs, it's the only part of the
# install the GUI user can write to.  Root runs some of the rest.
work="$destination/work"

# Our hermetic NVM installation.  The services install and update NVM and
# Node.js here on every start (see start-nodes.sh), so the GUI user owns it.
nvm_dir="$destination/nvm"

# Get the user currently logged in on the GUI.
gui_user=$(stat -f "%Su" /dev/console)

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
install -m 644 "$source_root/shaka-lab-node/node-setup.sh" "$destination"
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

# The log rotation config names the GUI user as the owner of new log files, so
# the services can keep writing them.
sed -i '' -e "s|\\\$GUI_USER|$gui_user|g" "$destination/shaka-lab-node-logrotate.conf"

# Service logs go here, so make sure the folder exists:
mkdir -p "$destination/logs"

# npm runs in the working directory, so it needs package.json there.
mkdir -p "$work"
install -m 644 "$source_root/shaka-lab-node/package.json" "$work"

# The app writes its PID files to fixed paths at the top level, which the GUI
# user can't write to.  Point them at the working directory.
ln -sfh "$work/shaka-lab-node.pid" "$destination/shaka-lab-node.pid"
ln -sfh "$work/shaka-lab-node.child.pid" "$destination/shaka-lab-node.child.pid"

# Don't install NVM or Node.js here.  As on Linux, the services do that when
# they start.  The proxy waits for them.
mkdir -p "$nvm_dir"

# Everything root runs stays owned by root: the scripts, the proxy, the log
# rotation config, and the folder that holds them.  The services only write to
# the working directory, the logs, and NVM.  The proxy runs as root on the GUI
# user's Node.js, just as it did on Homebrew's, which the GUI user owns too.
chown -R root:wheel "$destination"
chown -R "$gui_user" "$work" "$destination/logs" "$nvm_dir"

# The proxy runs as root, so its log goes in a folder that only root can write
# to.  See the comments in its plist.
mkdir -p /var/log/shaka-lab-node

# Install and load the loopback proxy LaunchDaemon.  It works around macOS
# Local Network Privacy, which otherwise blocks the test browser from
# reaching lab hosts.  It must be a root daemon for the privacy exemption.
# See local-network-privacy.md.
install -m 644 "$source_root/shaka-lab-node/macos/io.github.shaka-project.shaka-lab-node.local-network-proxy.plist" "$proxy_plist"
# restart-services.sh, at the end, loads it or reloads it.

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
