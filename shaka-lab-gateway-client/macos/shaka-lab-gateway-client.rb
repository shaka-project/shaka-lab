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

  # The path from the Cask definition to the full shaka-lab source.
  # We install files from there.
  source_root = "#{__dir__}/../shaka-lab-source"

  # The real work happens in install.sh and uninstall.sh, run as root.
  # If they fail, the package is not considered installed or uninstalled.
  preflight_steps do
    run "#{source_root}/shaka-lab-gateway-client/macos/install.sh",
        args: [source_root], sudo: true, print_stdout: true
  end

  # install.sh puts uninstall.sh outside of the tap, because Homebrew
  # uninstalls from its own saved copy of this Cask, which can't find files in
  # the tap.
  uninstall_preflight_steps do
    if_path_exists "/opt/shaka-lab-gateway-client/uninstall.sh" do
      run "/opt/shaka-lab-gateway-client/uninstall.sh",
          sudo: true, print_stdout: true
    end
  end

  # Upgrades uninstall the old version first, so a plain uninstall leaves this
  # machine bound, with what this package granted to lab users, and only
  # "brew uninstall --zap" takes those away and leaves the domain.  Leaving the
  # domain asks for the Active Directory Administrator password, and revoking
  # admin rights mid-upgrade would cut off lab admins.  By the time this runs,
  # the uninstall above has removed our files, so this can't run a script from
  # /opt/shaka-lab-gateway-client.
  #
  # Before leaving the domain, revoke what install.sh granted, which needs the
  # domain to resolve the group names:
  #  - SSH access for lab users.  Tolerate them not having been in the group.
  #    Use the plain group name, as install.sh does.
  #  - Local admin rights for lab admins.
  #  - The limit on DNS registration, so that macOS registers this machine's
  #    addresses on all interfaces again, as it does by default.
  zap script: {
        executable: "/bin/bash",
        args:       [
          "-c",
          "set -e; " \
          "domain=$(/usr/sbin/dsconfigad -show | awk '/Active Directory Domain/{print $NF}'); " \
          "if [[ \"$domain\" == lab.shaka ]]; then " \
          "if /usr/bin/dscl . -read /Groups/com.apple.access_ssh &>/dev/null; then " \
          "/usr/sbin/dseditgroup -o edit -d labusers -t group com.apple.access_ssh || true; " \
          "fi; " \
          "/usr/sbin/dsconfigad -nogroups; " \
          "/usr/sbin/dsconfigad -restrictDDNS \"\"; " \
          "/usr/sbin/dsconfigad -remove -u Administrator; " \
          "fi",
        ],
        sudo:       true,
      },
      delete: "/var/log/shaka-lab-gateway-client.log"
end
