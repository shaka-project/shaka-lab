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

# Applies Shaka Lab recommended settings on macOS.  Homebrew runs this as root
# from the Cask's preflight_steps.

# Fail on error
set -e

# Enable time sync
systemsetup -setusingnetworktime on
systemsetup -setnetworktimeserver time.apple.com

# Enable SSH.  By default, this is limited to admins.  Lab users are given
# access by shaka-lab-gateway-client.
systemsetup -setremotelogin on

# Enable VNC
/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
    -activate -configure \
    -access -on \
    -allowAccessFor -allUsers \
    -restart -agent \
    -privs -all

# Wake the system when the lid is opened (laptops)
pmset -a lidwake 1

# Restart automatically on power loss
pmset -a autorestart 1

# Never put the display to sleep
pmset -a displaysleep 0

# Never put the machine to sleep
pmset -c sleep 0  # while charging
pmset -b sleep 0  # while on battery

# Disable hibernation mode
pmset -a hibernatemode 0

# Disable the "power nap" feature
pmset -a powernap 0

# Check for OS updates automatically
defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist \
    AutomaticCheckEnabled -bool true

# Check for OS updates daily
defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist \
    ScheduleFrequency -int 1

# Download OS updates in the background
defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist \
    AutomaticDownload -int 1

# Install OS updates automatically
defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist \
    CriticalUpdateInstall -int 1

# Update apps automtically
defaults write /Library/Preferences/com.apple.commerce.plist \
    AutoUpdate -bool true

# Allow the App Store to reboot the machine when required for updates
defaults write /Library/Preferences/com.apple.commerce.plist \
    AutoUpdateRestartRequired -bool true
