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

# Homebrew docs: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula

class ShakaLabNode < Formula
  desc "Shaka Lab Node - Selenium grid nodes for the Shaka Lab"
  homepage "https://github.com/shaka-project/shaka-lab"
  license "Apache-2.0"

  # Formulae require a URL, but we don't actually have sources to download in
  # this way.  Instead, our tap repo includes the sources.  To satisfy
  # Homebrew, give a URL that never changes and returns no data.
  url "http://www.gstatic.com/generate_204"
  version "1.0.0"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  # Use --with-java to have Homebrew install Java from source.
  # Skip that if you already have Oracle Java installed.
  depends_on "java" => :optional

  # Use --with-docker to have Homebrew install Docker from source.
  # Docker is only needed to activate the Tizen node.
  # Skip that if you already have Docker installed or don't need Tizen.
  depends_on "docker" => :optional

  # We need at least node v12 installed.
  depends_on "node" => "12"

  def install
    # Detect our environment.  If we're building from the source repo (with
    # `brew install ./shaka-lab-node.rb`, we need a different root directory
    # than if this is installed as a tap.  Tap repos have a very specific
    # structure and naming scheme which differs from the layout of our
    # multi-platform source repo.

    # Assume we're installed as a tap.
    # The full source from this version is at this location in the tap repo.
    source_root = "#{__dir__}/../shaka-lab-source"
    unless File.exist? source_root
      # The source location for the tap repo doesn't exist.
      # Next, assume that we are building from the source repo.
      source_root = "#{__dir__}/../.."
    end
    unless File.exist? "#{source_root}/selenium-jar"
      # This doesn't appear to match the layout of the source repo, either.
      # Throw an error.
      raise "Unable to deduce shaka-lab formula repo context at #{__dir__}"
    end

    # Main shaka-lab-node files.
    FileUtils.install "#{source_root}/LICENSE.txt", prefix, :mode => 0644
    FileUtils.install "#{source_root}/selenium-jar/selenium-server-standalone-3.141.59.jar", prefix, :mode => 0644
    FileUtils.install "#{source_root}/shaka-lab-node/node-templates.yaml", prefix, :mode => 0644
    FileUtils.install "#{source_root}/shaka-lab-node/package.json", prefix, :mode => 0644
    FileUtils.install "#{source_root}/shaka-lab-node/start-nodes.js", prefix, :mode => 0644
    FileUtils.install "#{source_root}/shaka-lab-node/macos/log-wrapper.js", prefix, :mode => 0644
    FileUtils.install "#{source_root}/shaka-lab-node/macos/update-drivers.sh", prefix, :mode => 0755

    # Config file goes in /opt/homebrew/etc.  Don't overwrite it!
    unless File.exist? etc/"shaka-lab-node-config.yaml"
      FileUtils.install "#{source_root}/shaka-lab-node/shaka-lab-node-config.yaml", etc, :mode => 0644
    end

    # Service definitions.  Homebrew's service infrastructure will only let us
    # install one service per package, and we have both a background service
    # and a cron job.  Putting our plist files into a subfolder allows us to
    # bypass Homebrew's checks for plists.  This avoids a misleading message
    # from Homebrew with the wrong instructions to start the services.
    FileUtils.mkdir_p prefix/"plists"
    FileUtils.install "#{source_root}/shaka-lab-node/macos/shaka-lab-node-service.plist", prefix/"plists", :mode => 0644
    FileUtils.install "#{source_root}/shaka-lab-node/macos/shaka-lab-node-update.plist", prefix/"plists", :mode => 0644
    FileUtils.install "#{source_root}/shaka-lab-node/macos/stop-services.sh", prefix, :mode => 0755
    FileUtils.install "#{source_root}/shaka-lab-node/macos/restart-services.sh", prefix, :mode => 0755

    # The service definitions need hard-coded paths, and the Homebrew prefix
    # varies.  So replace "$HOMEBREW_PREFIX" in these plist files with the
    # current prefix (in the HOMEBREW_PREFIX variable).
    inreplace prefix/"plists/shaka-lab-node-service.plist", "$HOMEBREW_PREFIX", HOMEBREW_PREFIX
    inreplace prefix/"plists/shaka-lab-node-update.plist", "$HOMEBREW_PREFIX", HOMEBREW_PREFIX

    # Service logs go to /opt/homebrew/var/log
    FileUtils.mkdir_p var/"log"

    # Service PID file goes to /opt/homebrew/var/run
    FileUtils.mkdir_p var/"run"
  end

  # The output of this method is printed to the user after installation.
  #
  # We have to tell the user what to do to start the services because Homebrew
  # runs installation commands in a sandbox, so we can't start the service
  # automatically during installation.
  def caveats
    output = <<~EOS
      ******* ATTENTION *******
      Start services; please run:    #{opt_prefix}/restart-services.sh

      These tasks can't be done for you because of sandboxing.
      ******* ********* *******
    EOS

    return output
  end
end
