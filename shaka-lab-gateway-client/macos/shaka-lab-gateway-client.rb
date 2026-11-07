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

  # Tell homebrew that we won't "install" anything.  We do, just not using the
  # primitives for Casks, which are oriented around app bundles.
  stage_only true

  # Signal that this package does not need upgrading through "brew upgrade".
  auto_updates true

  # The path from the Cask definition to the full shaka-lab source.
  # We install files from there.
  source_root = "#{__dir__}/../shaka-lab-source"

  # The destination folder of shaka-lab-gateway-client files.
  destination = "/opt/shaka-lab-gateway-client"

  # The LaunchDaemon that creates home directories for lab users.
  homes_plist = "/Library/LaunchDaemons/io.github.shaka-project.shaka-lab-gateway-client.create-lab-homes.plist"

  # Use preflight so that if the commands fail, the package is not considered
  # installed.
  preflight do
    # NOTE: This utility runs /usr/bin/install, but through sudo.  It is
    # similar to FileUtils.install, but give us the ability to install files as
    # root.
    def sudo_install(source, destination, mode: "0644")
      system_command "/usr/bin/install", args: [
        "-m", mode, source, destination,
      ], sudo: true
    end

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

    # Allow lab users to log in over SSH.  When Remote Login is limited to
    # certain users, macOS keeps that list in the group com.apple.access_ssh.
    # If that group doesn't exist, Remote Login is already open to all users.
    if Kernel.system "/usr/bin/dscl", ".", "-read", "/Groups/com.apple.access_ssh", :out=>["/dev/null"], :err=>["/dev/null"]
      system_command "/usr/sbin/dseditgroup", args: [
        "-o", "edit", "-a", "LAB\\labusers", "-t", "group", "com.apple.access_ssh",
      ], sudo: true
    end

    # Install and load the LaunchDaemon that creates home directories for lab
    # users.  macOS only creates them on GUI login, and lab users log in over
    # SSH.  See create-lab-homes.sh.
    system_command "/bin/mkdir", args: ["-p", destination], sudo: true
    sudo_install "#{source_root}/shaka-lab-gateway-client/macos/create-lab-homes.sh", destination, mode: "0755"
    sudo_install "#{source_root}/shaka-lab-gateway-client/macos/io.github.shaka-project.shaka-lab-gateway-client.create-lab-homes.plist", homes_plist
    # Reload it.  Tolerate "not loaded" on a first install.
    begin
      system_command "/bin/launchctl", args: ["bootout", "system", homes_plist], sudo: true
    rescue StandardError
      # Was not loaded yet; ignore.
    end
    system_command "/bin/launchctl", args: ["bootstrap", "system", homes_plist], sudo: true
  end

  uninstall_preflight do
    # Unload the home directory LaunchDaemon before removing it.  Tolerate it
    # already being unloaded.  Home directories it created are left in place.
    begin
      system_command "/bin/launchctl", args: ["bootout", "system", homes_plist], sudo: true
    rescue StandardError
      # Already unloaded; ignore.
    end
    system_command "/bin/rm", args: [
      "-rf",
      destination,
      homes_plist,
      "/var/log/shaka-lab-gateway-client.log",
    ], sudo: true

    # Commands to leave the domain will fail if we're not in it, so check.
    domain = `dsconfigad -show | awk '/Active Directory Domain/{print $NF}'`.strip
    puts "Current domain = \"#{domain}\""

    if domain == "lab.shaka"
      # Revoke SSH access for lab users.  This must happen before leaving the
      # domain, while the group name can still be resolved.  Tolerate lab users
      # not having been in the group.
      if Kernel.system "/usr/bin/dscl", ".", "-read", "/Groups/com.apple.access_ssh", :out=>["/dev/null"], :err=>["/dev/null"]
        begin
          system_command "/usr/sbin/dseditgroup", args: [
            "-o", "edit", "-d", "LAB\\labusers", "-t", "group", "com.apple.access_ssh",
          ], sudo: true
        rescue StandardError
          # Not in the group; ignore.
        end
      end

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
