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

# Takes browsers out of quarantine on macOS.  Homebrew runs this as root from
# the Cask's postflight_steps, after the browser Casks are installed.

# Fail on error
set -e

# Take all browsers out of quarantine.  This has been found necessary for
# Firefox and Chrome at least in some cases.  Without this, the first time
# shaka-lab-node tries to start a browser, a dialog box may pop up from the OS
# and must be interacted with before tests can run for the first time.
#
# A browser that has updated itself is no longer quarantined, and removing a
# missing attribute is an error, so check first.
for app in "Firefox" "Google Chrome" "Microsoft Edge"; do
  if xattr -p com.apple.quarantine "/Applications/$app.app" &>/dev/null; then
    xattr -d com.apple.quarantine "/Applications/$app.app"
  fi
done
