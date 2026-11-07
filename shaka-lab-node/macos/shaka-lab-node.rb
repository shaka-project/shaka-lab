# Copyright 2022 Google LLC
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

# macOS Homebrew package definition for Shaka Lab Node.

# Homebrew docs: https://docs.brew.sh/Cask-Cookbook
#                https://rubydoc.brew.sh/Cask/Cask.html

cask "shaka-lab-node" do
  name "Shaka Lab Node"
  homepage "https://github.com/shaka-project/shaka-lab"
  desc "Selenium grid nodes for the Shaka Lab"

  # Casks require a URL, but we don't actually have sources to download in
  # this way.  Instead, our tap repo includes the sources.  To satisfy
  # Homebrew, give a URL that never changes and returns no data.
  url "http://www.gstatic.com/generate_204"
  version "1.0.0"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  # Casks can't have optional dependencies, so note to the user that Tizen can
  # enhance this package, if available.
  caveats "[Optional] To run a Tizen node, you also need Docker."

  # We need a working JDK, at least v14.
  # NOTE: We can't express a specific version in a Cask's dependencies.
  depends_on cask: "oracle-jdk"

  # We need node.js, any LTS.
  # NOTE: We can't express a specific version in a Cask's dependencies.
  depends_on formula: "node"

  # Tell homebrew that we won't "install" anything.  We do, just not using the
  # primitives for Casks, which are oriented around app bundles.
  stage_only true

  # The path from the Cask definition to the full shaka-lab source.
  # We install files from there.
  source_root = "#{__dir__}/../shaka-lab-source"

  # NOTE: WebDrivers are updated on node startup by start-nodes.js, and the
  # daily restart (config "daily_restart") re-runs that startup, so there is no
  # separate scheduled driver-update job.

  # The real work happens in install.sh and uninstall.sh, run as root.
  # If they fail, the package is not considered installed or uninstalled.
  preflight_steps do
    run "#{source_root}/shaka-lab-node/macos/install.sh",
        args: [source_root, "{{HOMEBREW_PREFIX}}"], sudo: true, print_stdout: true
  end

  # install.sh puts uninstall.sh outside of the tap, because Homebrew
  # uninstalls from its own saved copy of this Cask, which can't find files in
  # the tap.
  uninstall_preflight_steps do
    if_path_exists "/opt/shaka-lab-node/uninstall.sh" do
      run "/opt/shaka-lab-node/uninstall.sh", sudo: true, print_stdout: true
    end
  end
end
