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

# Runs on install and on upgrade.

# Stop on all errors.
$ErrorActionPreference = 'Stop'

# In case of a forced reinstall, which would skip the upgrade/uninstall steps,
# remove the service if it already exists.  Note that Remove-Service isn't
# available until PowerShell 6, and we can't guarantee that anything more
# recent than 5.1 is installed.
$service = Get-WmiObject -Class Win32_Service -Filter "Name='shaka-lab-node'"
if ($service) {
  echo "Stopping service..."
  Stop-Service -Name shaka-lab-node
  echo "Deleting service..."
  $service.delete()
}

# Install default config if none exists.
$nodeConfigFolder = "C:\ProgramData\shaka-lab-node";
if (-not(Test-Path -Path $nodeConfigFolder)) {
  New-Item -ItemType "directory" -Path $nodeConfigFolder
}

$nodeConfigPath = $nodeConfigFolder + "\node-config.yaml"
$defaultConfig = "$PSScriptRoot\default-node-config.yaml"
if (-not(Test-Path -Path $nodeConfigPath)) {
  echo "Installing default config to $nodeConfigPath"
  Copy-Item $defaultConfig -Destination $nodeConfigPath
} else {
  echo "Existing config found at $nodeConfigPath"
}

# Install initial WebDrivers
echo "Updating WebDrivers..."
& "$PSScriptRoot\update-drivers.cmd"

# Tell chocolatey not to shim any of the executables in this folder.
# This is done by adding a ".ignore" file next to each one.
echo "Suppressing Chocolatey shims..."
Get-ChildItem "$PSScriptRoot\*.exe" | ForEach-Object { New-Item "$_.ignore" -type file -force | Out-Null }

# Install the service.
echo "Installing service..."
& "$PSScriptRoot\shaka-lab-node-svc.exe" install

# Start the service.
echo "Starting service..."
& "$PSScriptRoot\shaka-lab-node-svc.exe" start
