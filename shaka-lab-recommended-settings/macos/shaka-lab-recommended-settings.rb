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

  # Use preflight so that if the commands fail, the package is not considered
  # installed.
  preflight do
    # Enable time sync
    system_command "/usr/sbin/systemsetup", args: [
      "-setusingnetworktime", "on",
    ], sudo: true
    system_command "/usr/sbin/systemsetup", args: [
      "-setnetworktimeserver", "time.apple.com",
    ], sudo: true

    # Enable SSH
    system_command "/usr/sbin/systemsetup", args: [
      "-setremotelogin", "on",
    ], sudo: true

    # Enable SSH for all users, not just admins
    # (This fails if run twice, so ignore failures here.  system_command
    # doesn't let us ignore failures, so use Kernel.system.)
    Kernel.system "/usr/bin/sudo", "/usr/sbin/dseditgroup", "-o", "delete", "-t", "group", "com.apple.access_ssh", :out=>["/dev/null"], :err=>["/dev/null"]

    # Enable VNC
    system_command "/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart", args: [
      "-activate", "-configure",
      "-access", "-on",
      "-allowAccessFor", "-allUsers",
      "-restart", "-agent",
      "-privs", "-all",
    ], sudo: true

    # Allow unsigned binaries (necessary for shaka-lab-node and WebDriver)
    system_command "/usr/sbin/spctl", args: [
      "--master-disable",
    ], sudo: true

    # Wake the system when the lid is opened (laptops)
    system_command "/usr/bin/pmset", args: [
      "-a", "lidwake", "1",
    ], sudo: true

    # Restart automatically on power loss
    system_command "/usr/bin/pmset", args: [
      "-a", "autorestart", "1",
    ], sudo: true

    # Never put the display to sleep
    system_command "/usr/bin/pmset", args: [
      "-a", "displaysleep", "0",
    ], sudo: true

    # Never put the machine to sleep
    system_command "/usr/bin/pmset", args: [
      "-c", "sleep", "0",  # while charging
    ], sudo: true
    system_command "/usr/bin/pmset", args: [
      "-b", "sleep", "0",  # while on battery
    ], sudo: true

    # Disable hibernation mode
    system_command "/usr/bin/pmset", args: [
      "-a", "hibernatemode", "0",
    ], sudo: true

    # Disable the "power nap" feature
    system_command "/usr/bin/pmset", args: [
      "-a", "powernap", "0",
    ], sudo: true

    # Check for OS updates automatically
    system_command "/usr/bin/defaults", args: [
      "write", "/Library/Preferences/com.apple.SoftwareUpdate.plist",
      "AutomaticCheckEnabled", "-bool", "true",
    ], sudo: true

    # Check for OS updates daily
    system_command "/usr/bin/defaults", args: [
      "write", "/Library/Preferences/com.apple.SoftwareUpdate.plist",
      "ScheduleFrequency", "-int", "1",
    ], sudo: true

    # Download OS updates in the background
    system_command "/usr/bin/defaults", args: [
      "write", "/Library/Preferences/com.apple.SoftwareUpdate.plist",
      "AutomaticDownload", "-int", "1",
    ], sudo: true

    # Install OS updates automatically
    system_command "/usr/bin/defaults", args: [
      "write", "/Library/Preferences/com.apple.SoftwareUpdate.plist",
      "CriticalUpdateInstall", "-int", "1",
    ], sudo: true

    # Update apps automtically
    system_command "/usr/bin/defaults", args: [
      "write", "/Library/Preferences/com.apple.commerce.plist",
      "AutoUpdate", "-bool", "true",
    ], sudo: true

    # Allow the App Store to reboot the machine when required for updates
    system_command "/usr/bin/defaults", args: [
      "write", "/Library/Preferences/com.apple.commerce.plist",
      "AutoUpdateRestartRequired", "-bool", "true",
    ], sudo: true
  end

  # These commands depend on kcpassword, so they go into postflight.
  postflight do
    # Prompt for the user's password to enable autologin
    require 'io/console'
    puts "Enabling autologin..."
    password = IO::console.getpass "Enter user password: "

    # Enable autologin, part 1: Write obfuscated password read by logind
    system_command "#{HOMEBREW_PREFIX}/bin/kcpassword", args: [
      password,
    ], sudo: true
    # Enable autologin, part 2: Set the username read by logind
    system_command "/usr/bin/defaults", args: [
      "write", "/Library/Preferences/com.apple.loginwindow",
      "autoLoginUser", ENV['USER'],
    ], sudo: true
  end
end
