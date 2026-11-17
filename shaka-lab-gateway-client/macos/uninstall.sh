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

# Uninstalls shaka-lab-gateway-client on macOS.  Homebrew runs this as root
# from the Cask's uninstall_preflight_steps.  install.sh puts it in
# /opt/shaka-lab-gateway-client.
#
# This leaves the machine bound to the domain, because upgrades uninstall the
# old version first, and leaving the domain would make every upgrade ask for
# the Active Directory Administrator password.  "brew uninstall --zap" leaves
# the domain, from the Cask's zap stanza.

# Fail on error
set -e

destination="/opt/shaka-lab-gateway-client"
homes_plist="/Library/LaunchDaemons/io.github.shaka-project.shaka-lab-gateway-client.create-lab-homes.plist"

# Stop creating home directories for lab users.  Tolerate it already being
# unloaded.  Home directories it created are left in place.
launchctl bootout system "$homes_plist" 2>/dev/null || true

# Revoke what this package granted to lab users.  This needs the domain, to
# resolve the group names, so skip it if this machine has already left.
domain=$(dsconfigad -show | awk '/Active Directory Domain/{print $NF}')
if [[ "$domain" == "lab.shaka" ]]; then
  # Revoke SSH access for lab users.  Tolerate lab users not having been in
  # the group.
  if dscl . -read /Groups/com.apple.access_ssh &>/dev/null; then
    dseditgroup -o edit -d 'LAB\labusers' -t group com.apple.access_ssh || true
  fi

  # Revoke local admin rights for lab admins.
  dsconfigad -nogroups
fi

# Remove our files.
rm -rf "$destination" "$homes_plist" /var/log/shaka-lab-gateway-client.log \
    /etc/ssh/sshd_config.d/200-shaka-lab-gateway-client.conf \
    /etc/ssh/ssh_config.d/200-shaka-lab-gateway-client.conf
