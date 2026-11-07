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

# Configures Safari for Shaka Lab on macOS.  Homebrew runs this as root from
# the Cask's preflight_steps.  Settings for the installing user run as that
# user, through sudo -u.
#
# Usage: install.sh <Homebrew prefix>

# Fail on error
set -e

homebrew_prefix="$1"

# Enable the "develop" menu for Safari
sudo -u "$SUDO_USER" defaults write com.apple.Safari.SandboxBroker \
    ShowDevelopMenu -bool true
sudo -u "$SUDO_USER" defaults write com.apple.Safari \
    IncludeDevelopMenu -bool true

# Enable the "develop" menu for Safari Tech Preview
sudo -u "$SUDO_USER" defaults write com.apple.SafariTechnologyPreview.SandboxBroker \
    ShowDevelopMenu -bool true
sudo -u "$SUDO_USER" defaults write com.apple.SafariTechnologyPreview \
    IncludeDevelopMenu -bool true

# Enable remote automation for Safari
safaridriver --enable

# Attempt to install the Safari Tech Preview cask.  This is not an actual cask
# dependency because it is only available on the latest macOS versions.  If
# this command fails, the shaka-lab-browsers install still succeeds.  Homebrew
# refuses to run as root, so run it as the installing user.
if sudo -u "$SUDO_USER" "$homebrew_prefix/bin/brew" install --cask safari-technology-preview &>/dev/null; then
  # Enable remote automation for Safari Tech Preview
  "/Applications/Safari Technology Preview.app/Contents/MacOS/safaridriver" --enable
else
  echo "*** NOTE: Safari Technology Preview could not be installed. ***"
  echo "*** Safari TP install requires the latest version of macOS. ***"
fi
