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

# Installs shaka-lab-gateway-client on macOS.  Homebrew runs this as root from
# the Cask's preflight_steps.
#
# Usage: install.sh <path to shaka-lab source>

# Fail on error
set -e

source_root="$1"
destination="/opt/shaka-lab-gateway-client"
homes_plist="/Library/LaunchDaemons/io.github.shaka-project.shaka-lab-gateway-client.create-lab-homes.plist"

# Commands to join the domain will fail if we're already in it, so check.
domain=$(dsconfigad -show | awk '/Active Directory Domain/{print $NF}')
echo "Current domain = \"$domain\""

if [[ "$domain" == "lab.shaka" ]]; then
  echo "Already a member of the Shaka Lab domain."
else
  # Perform a one-time time sync, since this is critical for joining AD.
  # In contrast, shaka-lab-recommended-settings will set ongoing time sync.
  sntp -sS time.apple.com

  echo "Joining Shaka Lab domain via Shaka Lab Gateway."
  echo "When prompted for \"Administrator's Password\", enter your Active Directory Administrator password."
  dsconfigad -domain lab.shaka -u Administrator
  echo "Successfully joined the Shaka Lab domain!"
fi

# Give lab admins local admin rights, including sudo, as the Linux client
# does.  This replaces any other admin groups set for the domain.
dsconfigad -groups 'LAB\labadmins'

# Allow lab users to log in over SSH.  When Remote Login is limited to certain
# users, macOS keeps that list in the group com.apple.access_ssh.  If that
# group doesn't exist, Remote Login is already open to all users.
if dscl . -read /Groups/com.apple.access_ssh &>/dev/null; then
  dseditgroup -o edit -a 'LAB\labusers' -t group com.apple.access_ssh
fi

# Install the uninstall script outside of the tap.  Homebrew uninstalls from
# its own saved copy of the Cask, which can't find files in the tap.
mkdir -p "$destination"
install -m 755 "$source_root/shaka-lab-gateway-client/macos/uninstall.sh" "$destination/"

# Install and load the LaunchDaemon that creates home directories for lab
# users.  macOS only creates them on GUI login, and lab users log in over SSH.
# See create-lab-homes.sh.
install -m 755 "$source_root/shaka-lab-gateway-client/macos/create-lab-homes.sh" "$destination/"
install -m 644 "$source_root/shaka-lab-gateway-client/macos/io.github.shaka-project.shaka-lab-gateway-client.create-lab-homes.plist" "$homes_plist"
# Reload it.  Tolerate "not loaded" on a first install.
launchctl bootout system "$homes_plist" 2>/dev/null || true
launchctl bootstrap system "$homes_plist"
