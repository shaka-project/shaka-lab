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

# Enables autologin for the user installing shaka-lab-recommended-settings on
# macOS.  Homebrew runs this as root from the Cask's postflight_steps, after
# installing kcpassword.
#
# Usage: postflight.sh <Homebrew prefix>

# Fail on error
set -e

homebrew_prefix="$1"

# Upgrades reinstall this package, so don't ask again if autologin is already
# set up for this user.  To store a new password, for example after the user's
# password changes, delete /etc/kcpassword and reinstall this package.
autologin_user=$(defaults read /Library/Preferences/com.apple.loginwindow \
    autoLoginUser 2>/dev/null || true)
if [[ -e /etc/kcpassword && "$autologin_user" == "$SUDO_USER" ]]; then
  echo "Autologin is already enabled for $SUDO_USER."
  exit 0
fi

# Prompt for the user's password to enable autologin.  Homebrew doesn't give us
# its terminal on stdin, so use /dev/tty directly.
echo "Enabling autologin..."
printf "Enter user password: " > /dev/tty
read -rs password < /dev/tty
printf "\n" > /dev/tty

# Enable autologin, part 1: Write obfuscated password read by logind
"$homebrew_prefix/bin/kcpassword" "$password"

# Enable autologin, part 2: Set the username read by logind
defaults write /Library/Preferences/com.apple.loginwindow \
    autoLoginUser "$SUDO_USER"
