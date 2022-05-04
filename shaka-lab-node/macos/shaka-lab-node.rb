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

# macOS Homebrew package definition for for Shaka Lab Node.

# Homebrew docs: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula

class ShakaLabNode < Formula
  desc "Shaka Lab Node - Selenium grid nodes for the Shaka Lab"
  homepage "https://github.com/shaka-project/shaka-lab"
  license "Apache-2.0"

  # Formulae require a URL, but we don't actually have sources to download in
  # this way.  To satisfy Homebrew, give a URL that never changes and returns
  # no data.
  url "http://www.gstatic.com/generate_204"
  version "1.0.0"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  # Use --with-java to have Homebrew install Java from source.
  # Skip that if you already have Oracle Java installed.
  depends_on "java" => :optional

  # Use --with-docker to have Homebrew install Docker from source.
  # Docker is only needed to activate the Tizen node.
  # Skip that if you already have Docker installed or don't need TIzen.
  depends_on "docker" => :optional

  # We need at least node v12 installed.
  depends_on "node" => "12"

  def install
    source_root = "#{__dir__}/../.."

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

    # Service definitions.
    FileUtils.install "#{source_root}/shaka-lab-node/macos/shaka-lab-node-service.plist", prefix, :mode => 0644
    FileUtils.install "#{source_root}/shaka-lab-node/macos/shaka-lab-node-update.plist", prefix, :mode => 0644
    FileUtils.install "#{source_root}/shaka-lab-node/macos/stop-services.sh", prefix, :mode => 0755
    FileUtils.install "#{source_root}/shaka-lab-node/macos/restart-services.sh", prefix, :mode => 0755

    # Service logs go to /opt/homebrew/var/log
    FileUtils.mkdir_p var/"log"

    # Service PID file goes to /opt/homebrew/var/run
    FileUtils.mkdir_p var/"run"
  end

  # When Homebrew sees that we have installed plist files, it will issue a
  # "caveat" message with instructions on how to start the service.  Those
  # instructions will fail.  We don't use Homebrew's service infrastructure
  # because it will only let us install one service per package, and we have
  # both a background service and a cron job.
  #
  # We can't suppresss Homebrew's "caveat" message, but we can add one of our
  # own.  This gets printed before the message we can't control.
  def caveats
    <<~EOS
      ******* ATTENTION *******
      Please run #{opt_prefix}/restart-services.sh
      This can't be done for you because of sandboxing.
      ******* ********* *******

      Also, please ignore the mention of "brew services" below.
      Our services don't fit homebrew's expectations,
      so the command below doesn't work.
    EOS
  end
end
