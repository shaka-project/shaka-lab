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
$ErrorActionPreference = "Stop"

$installFolder = "C:\ProgramData\chocolatey\lib\shaka-lab-node"
$runtimeFolder = "C:\ProgramData\shaka-lab-node"

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
if (-not(Test-Path -Path $runtimeFolder)) {
  New-Item -ItemType "directory" -Path $runtimeFolder
}
$nodeConfigPath = $runtimeFolder + "\shaka-lab-node-config.yaml"
$defaultConfig = "$installFolder\default-node-config.yaml"
if (-not(Test-Path -Path $nodeConfigPath)) {
  echo "Installing default config to $nodeConfigPath"
  Copy-Item $defaultConfig -Destination $nodeConfigPath
} else {
  echo "Existing config found at $nodeConfigPath"
}

# Install the service.  This also creates the virtual service account.
echo "Installing service..."
& "$installFolder\shaka-lab-node-svc.exe" install

# Allow the virtual service account to write to the runtime folder.
# This must come after service installation, which creates the virtual service
# account.
echo "Setting ACL..."
$ACL = Get-ACL -Path $runtimeFolder
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    # This user
    "NT SERVICE\shaka-lab-node",
    # Can do anything
    "FullControl",
    # And the setting will be inherited by children of the folder.
    "ContainerInherit,ObjectInherit", "InheritOnly",
    "Allow")
$ACL.SetAccessRule($AccessRule)
$ACL | Set-Acl -Path $runtimeFolder

# Start the service.
echo "Starting service..."
& "$installFolder\shaka-lab-node-svc.exe" start

# Register the scheduled WebDriver update task (if not already installed).
$task = Get-ScheduledTask | Where-Object -FilterScript { $_.TaskName -eq "shaka-lab-node-update" }
if ($task) {
  echo "WebDriver update task already registered..."
} else {
  echo "Registering WebDriver update task..."
  $action = New-ScheduledTaskAction -Execute "$installFolder\update-drivers.cmd"
  $trigger = New-ScheduledTaskTrigger -Daily -At 1am  # local time
  Register-ScheduledTask `
      -TaskName shaka-lab-node-update `
      -Description "Updates WebDrivers nightly for shaka-lab-node" `
      -Action $action `
      -User "NT SERVICE\shaka-lab-node" `
      -Trigger $trigger | Out-Null
}
