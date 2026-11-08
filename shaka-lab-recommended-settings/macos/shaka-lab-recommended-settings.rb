# Copyright 2023 Google LLC
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

# macOS Homebrew package definition for Shaka Lab Recommended Settings.

# Homebrew docs: https://docs.brew.sh/Cask-Cookbook
#                https://rubydoc.brew.sh/Cask/Cask.html

cask "shaka-lab-recommended-settings" do
  name "Shaka Lab Recommended Settings"
  homepage "https://github.com/shaka-project/shaka-lab"
  desc "Recommended OS settings for a Shaka Lab environment"

  # This Cask actually downloads a third-party tool called kcpassword, which is
  # necessary to set the current user for autologin.  Autologin is necessary
  # for test automation in browsers.  The tool is small and isn't expected to
  # change much, so we just pin this version.  The URL and sha256 are taken
  # from https://github.com/xfreebird/homebrew-utils/blob/master/kcpassword.rb
  url "https://github.com/xfreebird/kcpassword/archive/1.1.0.tar.gz"
  sha256 "318afc8f1dadf4bcce60b7f83dc4009d37ec45124c04cb0346c762aaa1b2d6d5"

  # This is the version of shaka-lab-recommended-settings itself, not the
  # kcpassword source above.
  version "1.0.0"

  binary "kcpassword-1.1.0/kcpassword"

  # Signal that this package does not need upgrading through "brew upgrade".
  auto_updates true

  # The path from the Cask definition to the full shaka-lab source.
  source_root = "#{__dir__}/../shaka-lab-source"

  # The real work happens in install.sh and postflight.sh, run as root.
  # If they fail, the package is not considered installed.
  preflight_steps do
    run "#{source_root}/shaka-lab-recommended-settings/macos/install.sh",
        sudo: true, print_stdout: true
  end

  # Autologin depends on kcpassword, so it goes into postflight.
  postflight_steps do
    run "#{source_root}/shaka-lab-recommended-settings/macos/postflight.sh",
        args: ["{{HOMEBREW_PREFIX}}"], sudo: true, print_stdout: true
  end
end
