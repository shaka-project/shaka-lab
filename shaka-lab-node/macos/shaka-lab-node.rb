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

# macOS Homebrew package definition for for Shaka Lab Selenium nodes.

# Homebrew docs: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula

class ShakaLabNode < Formula
  desc "Shaka Lab Selenium nodes"
  homepage "https://github.com/shaka-project/shaka-lab"
  url "http://www.gstatic.com/generate_204"
  version "1.0.0"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  license "Apache-2.0"

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
    # Main shaka-lab-node files.
    FileUtils.install "#{__dir__}/../../LICENSE.txt", prefix, :mode => 0644
    FileUtils.install "#{__dir__}/../../selenium-jar/selenium-server-standalone-3.141.59.jar", prefix, :mode => 0644
    FileUtils.install "#{__dir__}/../node-templates.yaml", prefix, :mode => 0644
    FileUtils.install "#{__dir__}/../package.json", prefix, :mode => 0644
    FileUtils.install "#{__dir__}/../start-nodes.js", prefix, :mode => 0755
    FileUtils.install "#{__dir__}/update-drivers.sh", prefix, :mode => 0755

    # Config file goes in /opt/homebrew/etc.  Don't overwrite it!
    unless File.exist? etc/"shaka-lab-node-config.yaml"
      FileUtils.install "#{__dir__}/../shaka-lab-node-config.yaml", etc, :mode => 0644
    end

    # Service definitions.
    FileUtils.install "#{__dir__}/shaka-lab-node-service.plist", prefix, :mode => 0644
    FileUtils.install "#{__dir__}/shaka-lab-node-update.plist", prefix, :mode => 0644
    FileUtils.install "#{__dir__}/restart-services.sh", prefix, :mode => 0755

    # Service logs go to /opt/homebrew/var/log
    FileUtils.mkdir_p var/"log"
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
      Please run #{opt_prefix}/restart-services.sh
      This can't be done for you because of sandboxing.

      Also, please ignore the mention of "brew services" below.
      Our services don't fit homebrew's expectations,
      so the command below doesn't work.
    EOS
  end
end
