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

# Fail on error
set -e

destination="/opt/shaka-lab-gateway-client"
homes_plist="/Library/LaunchDaemons/io.github.shaka-project.shaka-lab-gateway-client.create-lab-homes.plist"

# Stop creating home directories for lab users.  Tolerate it already being
# unloaded.  Home directories it created are left in place.
launchctl bootout system "$homes_plist" 2>/dev/null || true

# Commands to leave the domain will fail if we're not in it, so check.
domain=$(dsconfigad -show | awk '/Active Directory Domain/{print $NF}')
echo "Current domain = \"$domain\""

if [[ "$domain" == "lab.shaka" ]]; then
  # Revoke SSH access for lab users.  This must happen before leaving the
  # domain, while the group name can still be resolved.  Tolerate lab users
  # not having been in the group.
  if dscl . -read /Groups/com.apple.access_ssh &>/dev/null; then
    dseditgroup -o edit -d 'LAB\labusers' -t group com.apple.access_ssh || true
  fi

  # Revoke local admin rights for lab admins.
  dsconfigad -nogroups

  echo "Leaving the Shaka Lab domain via Shaka Lab Gateway."
  echo "When prompted for \"Administrator's Password\", enter your Active Directory Administrator password."
  dsconfigad -remove -u Administrator
  echo "Successfully left the Shaka Lab domain."
else
  echo "Already left the Shaka Lab domain."
fi

# Remove our files last, so that if leaving the domain fails, uninstalling
# again will retry it.
rm -rf "$destination" "$homes_plist" /var/log/shaka-lab-gateway-client.log
