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

  # Use preflight so that if the commands fail, the package is not considered
  # installed.
  preflight do
    # Enable the "develop" menu for Safari
    system_command "/usr/bin/defaults", args: [
      "write", "com.apple.Safari.SandboxBroker", "ShowDevelopMenu",
      "-bool", "true",
    ]
    system_command "/usr/bin/defaults", args: [
      "write", "com.apple.Safari", "IncludeDevelopMenu",
      "-bool", "true",
    ]

    # Enable the "develop" menu for Safari Tech Preview
    system_command "/usr/bin/defaults", args: [
      "write", "com.apple.SafariTechnologyPreview.SandboxBroker", "ShowDevelopMenu",
      "-bool", "true",
    ]
    system_command "/usr/bin/defaults", args: [
      "write", "com.apple.SafariTechnologyPreview", "IncludeDevelopMenu",
      "-bool", "true",
    ]

    # Enable remote automation for Safari
    system_command "/usr/bin/safaridriver",
        args: [ "--enable" ], sudo: true

    # Attempt to install the Safari Tech Preview cask
    # This is not an actual cask dependency because it is only available on the
    # latest macOS versions.  If this command fails, the shaka-lab-browsers
    # install still succeeds.
    # Here we use ruby's native system method (Kernel.system) instead of
    # Homebrew's so that we can get an exit code instead of failing.
    if Kernel.system "brew", "install", "--cask", "safari-technology-preview", :out=>["/dev/null"], :err=>["/dev/null"]
      # Enable remote automation for Safari Tech Preview
      # Safari TP is only available on the latest macOS versions
      system_command "/Applications/Safari Technology Preview.app/Contents/MacOS/safaridriver",
          args: [ "--enable" ], sudo: true
    else
      puts "*** NOTE: Safari Technology Preview could not be installed. ***"
      puts "*** Safari TP install requires the latest version of macOS. ***"
    end
  end

  postflight do
    # Take Firefox out of quarantine.  I'm not sure why this is only needed for
    # Firefox and not Chrome or Edge.  Without this, the first time
    # shaka-lab-node tries to start Firefox, a dialog box pops up from the OS
    # and must be interacted with before tests can run for the first time.
    system_command "/usr/bin/xattr", args: [
      "-d", "com.apple.quarantine", "/Applications/Firefox.app",
    ]
  end

  depends_on cask: "firefox"
  depends_on cask: "google-chrome"
  depends_on cask: "microsoft-edge"
end
