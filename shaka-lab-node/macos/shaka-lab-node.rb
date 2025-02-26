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

  # We need node.js, at least v12.
  # NOTE: We can't express a specific version in a Cask's dependencies.
  depends_on formula: "node"

  # Tell homebrew that we won't "install" anything.  We do, just not using the
  # primitives for Casks, which are oriented around app bundles.
  stage_only true

  # The path from the Cask definition to the full shaka-lab source.
  # We install files from there.
  source_root = "#{__dir__}/../shaka-lab-source"

  # The destination folder of most shaka-lab-node files.
  destination = "/opt/shaka-lab-node"

  # Install a launchd service to update the drivers.
  service do
    run ["/usr/bin/open", "-n", "/Applications/shaka-lab-node-update-drivers.app"]
    # Run daily at 1am
    run_type :cron
    cron "0 1 * * *"
  end

  # Use preflight so that if the commands fail, the package is not considered
  # installed.
  preflight do
    # NOTE: The inreplace command for Formulae is not available in Casks.
    # Since it is very simple, we replicate it here to keep the installation
    # code more readable.  This version can also write to files owned by root.
    def sudo_inreplace(path, original_text, new_text)
      contents = File.read(path)
      contents.gsub!(original_text, new_text)

      temp_file = Tempfile.new('shaka-lab-node-install-')
      begin
        temp_file.write(contents)
        temp_file.flush
        system_command "/bin/cp", args: [temp_file.path, path], sudo: true
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    # NOTE: This utility runs /usr/bin/install, but through sudo.  It is
    # similar to FileUtils.install, but give us the ability to install files as
    # root.
    def sudo_install(source, destination, mode: "0644")
      system_command "/usr/bin/install", args: [
        "-m", mode, source, destination,
      ], sudo: true
    end

    # NOTE: Similar to FileUtils.mkdir_p, but through sudo.
    def sudo_mkdir_p(path)
      system_command "/bin/mkdir", args: ["-p", path], sudo: true
    end

    # Create the destination directory.
    sudo_mkdir_p destination

    # Main shaka-lab-node files.
    sudo_install "#{source_root}/LICENSE.txt", destination
    sudo_install "#{source_root}/selenium-jar/selenium-server-standalone-3.141.59.jar", destination
    sudo_install "#{source_root}/shaka-lab-node/node-templates.yaml", destination
    sudo_install "#{source_root}/shaka-lab-node/package.json", destination
    sudo_install "#{source_root}/shaka-lab-node/start-nodes.js", destination
    for path in Dir.glob("#{source_root}/shaka-lab-node/macos/*") do
      unless path.end_with?(".app")
        sudo_install path, destination
      end
    end
    # Mark the shell scripts as executable.
    for path in Dir.glob("#{source_root}/shaka-lab-node/macos/*.sh") do
      sudo_install path, destination, mode: "0755"
    end

    # Don't overwrite the config file if it already exists!
    # This file will be left in tact during uninstall.
    unless File.exist? "/etc/shaka-lab-node-config.yaml"
      sudo_install "#{source_root}/shaka-lab-node/shaka-lab-node-config.yaml", "/etc/"
    end

    # Certain files need hard-coded paths to node.js, which is installed under
    # a variable Homebrew prefix.  So replace the string "$HOMEBREW_PREFIX"
    # with the current prefix (in the HOMEBREW_PREFIX variable).
    sudo_inreplace "#{destination}/update-drivers.sh", "$HOMEBREW_PREFIX", HOMEBREW_PREFIX

    # Service logs go here, so make sure the folder exists:
    sudo_mkdir_p "#{destination}/logs"

    # Get the user currently logged in on the GUI.
    GUI_USER = `stat -f "%Su" /dev/console`.strip

    # Make the destination directory owned by the logged-in GUI user.
    # Make sure the service account can write to all the necessary locations in
    # the installation to do updates and logging:
    system_command "/usr/sbin/chown", args: [
      "-R", GUI_USER, destination,
    ], sudo: true

    # Symlink the log rotation config file into its required location.
    system_command "/bin/ln", args: [
      "-sf", "#{destination}/shaka-lab-node-logrotate.conf",
      "/etc/newsyslog.d/",
    ], sudo: true

    # Copy the .app bundles to /Applications/
    system_command "/bin/cp", args: [
      "-R",
      "#{source_root}/shaka-lab-node/macos/shaka-lab-node.app",
      "#{source_root}/shaka-lab-node/macos/shaka-lab-node-update-drivers.app",
      "/Applications/",
    ], sudo: true

    # Set shaka-lab-node to start on login.
    system_command "/usr/bin/osascript", args: [
      "-e",
      "tell application \"System Events\" to make login item at end with properties {path:\"/Applications/shaka-lab-node.app\", hidden:false}",
    ]

    # Now start/restart the services.
    puts "Restarting services..."
    system_command "#{destination}/restart-services.sh", sudo: true
    puts "Done!"
  end

  uninstall_preflight do
    puts "Stopping services..."
    system_command "#{destination}/stop-services.sh", sudo: true
    puts "Done!"

    # Remove the main installation and symlinks.
    system_command "/bin/rm", args: [
      "-rf",
      "#{destination}",
      "/etc/newsyslog.d/shaka-lab-node-logrotate.conf",
      "/Applications/shaka-lab-node.app",
      "/Applications/shaka-lab-node-update-drivers.app",
    ], sudo: true
  end
end
