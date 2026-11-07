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

# macOS Homebrew package definition for Shaka Lab Browsers.

# Homebrew docs: https://docs.brew.sh/Cask-Cookbook
#                https://rubydoc.brew.sh/Cask/Cask.html

cask "shaka-lab-browsers" do
  name "Shaka Lab Browsers"
  homepage "https://github.com/shaka-project/shaka-lab"
  desc "All major browsers for the Shaka Lab"

  # Casks require a URL, but we don't actually have sources to download in
  # this way.  Instead, our tap repo includes the sources.  To satisfy
  # Homebrew, give a URL that never changes and returns no data.
  url "http://www.gstatic.com/generate_204"
  version "1.0.0"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  # We don't install anything.  We only depend on other casks.
  stage_only true

  # Signal that this package does not need upgrading through "brew upgrade".
  auto_updates true

  # The path from the Cask definition to the full shaka-lab source.
  source_root = "#{__dir__}/../shaka-lab-source"

  # The real work happens in install.sh and postflight.sh, run as root.
  # If they fail, the package is not considered installed.
  preflight_steps do
    run "#{source_root}/shaka-lab-browsers/macos/install.sh",
        args: ["{{HOMEBREW_PREFIX}}"], sudo: true, print_stdout: true
  end

  # Quarantine is removed after the browser Casks are installed.
  postflight_steps do
    run "#{source_root}/shaka-lab-browsers/macos/postflight.sh",
        sudo: true, print_stdout: true
  end

  depends_on cask: "firefox"
  depends_on cask: "google-chrome"
  depends_on cask: "microsoft-edge"
end
