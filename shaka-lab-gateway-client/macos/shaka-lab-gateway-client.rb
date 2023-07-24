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

# macOS Homebrew package definition for Shaka Lab Gateway Client.

# Homebrew docs: https://docs.brew.sh/Cask-Cookbook
#                https://rubydoc.brew.sh/Cask/Cask.html

cask "shaka-lab-gateway-client" do
  name "Shaka Lab Gateway Client"
  homepage "https://github.com/shaka-project/shaka-lab"
  desc "Allows Active Directory users from Shaka Lab Gateway to log in"

  # Casks require a URL, but we don't actually have sources to download in
  # this way.  Instead, our tap repo includes the sources.  To satisfy
  # Homebrew, give a URL that never changes and returns no data.
  url "http://www.gstatic.com/generate_204"
  version "1.0.0"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  # We don't install anything.  We only invoke OS tools to configure AD login.
  stage_only true

  # Use preflight so that if the commands fail, the package is not considered
  # installed.
  preflight do
    # Commands to join the domain will fail if we're already in it, so check.
    domain = `dsconfigad -show | awk '/Active Directory Domain/{print $NF}'`.strip
    puts "Current domain = \"#{domain}\""

    if domain == "lab.shaka"
      puts "Already a member of the Shaka Lab domain."
    else
      # Perform a one-time time sync, since this is critical for joining AD.
      # In contrast, shaka-lab-recommended-settings will set ongoing time sync.
      system_command "/usr/bin/sntp", args: [
        "-sS", "time.apple.com",
      ], sudo: true

      puts "Joining Shaka Lab domain via Shaka Lab Gateway."
      puts "When prompted for \"Password\", enter your own password for sudo."
      puts "When prompted for \"Administrator's Password\", enter your Active Directory Administrator password."

      system_command "/usr/sbin/dsconfigad", args: [
        "-domain", "lab.shaka",
        "-u", "Administrator",
      ], sudo: true

      puts "Successfully joined the Shaka Lab domain!"
    end
  end

  uninstall_preflight do
    # Commands to leave the domain will fail if we're not in it, so check.
    domain = `dsconfigad -show | awk '/Active Directory Domain/{print $NF}'`.strip
    puts "Current domain = \"#{domain}\""

    if domain == "lab.shaka"
      puts "Leaving the Shaka Lab domain via Shaka Lab Gateway."
      puts "When prompted for \"Password\", enter your own password for sudo."
      puts "When prompted for \"Administrator's Password\", enter your Active Directory Administrator password."

      system_command "/usr/sbin/dsconfigad", args: [
        "-remove",
        "-u", "Administrator",
      ], sudo: true

      puts "Successfully left the Shaka Lab domain."
    else
      puts "Already left the Shaka Lab domain."
    end
  end
end
