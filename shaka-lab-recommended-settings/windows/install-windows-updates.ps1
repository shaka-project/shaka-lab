# Copyright 2026 Google LLC
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

# Installs all available Windows and driver updates.  Needs admin rights.
#
# This works over SSH.  The Windows Update API refuses to download or install
# updates from an SSH session ("Access is denied", 0x80070005), so the updates
# run as SYSTEM in a scheduled task, and this script waits for the task and
# prints its log.
#
# The shaka-lab-update-os command runs this after upgrading Chocolatey
# packages.  See shaka-lab-update-os.ps1.


# Stop on all errors
$ErrorActionPreference = "Stop"

$taskName = "shaka-lab-windows-updates"
$logFolder = "$env:ProgramData\shaka-lab-recommended-settings"
$logFile = "$logFolder\windows-updates.log"


# Install the PSWindowsUpdate module for all users, so that every admin and the
# SYSTEM account share one copy.
if (-Not (Get-Module -ListAvailable -Name PSWindowsUpdate |
          ? { $_.ModuleBase.StartsWith($env:ProgramFiles) })) {
  echo "`nInstalling the PSWindowsUpdate module...`n"
  Install-PackageProvider -Name NuGet -Scope AllUsers -Force | Out-Null
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module PSWindowsUpdate -Scope AllUsers -Force
}


# The command the task runs as SYSTEM.  It exits with 3010 if a restart is
# needed to finish installing updates, the usual Windows code for that.
#
# -AcceptAll installs every update without asking, and -IgnoreReboot skips the
# question about restarting, which nobody would be there to answer.
$taskCommand = @"
try {
  Import-Module PSWindowsUpdate
  Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot -Confirm:`$false |
      Format-Table -AutoSize | Out-String -Width 200 |
      Out-File -FilePath '$logFile' -Encoding utf8
  if (Get-WURebootStatus -Silent) {
    exit 3010
  }
  exit 0
} catch {
  `$_ | Out-String | Out-File -FilePath '$logFile' -Encoding utf8 -Append
  exit 1
}
"@
# Pass the command encoded, to avoid quoting problems.
$encodedCommand = [Convert]::ToBase64String(
    [System.Text.Encoding]::Unicode.GetBytes($taskCommand))

if (-Not (Test-Path $logFolder)) {
  New-Item -ItemType Directory -Path $logFolder | Out-Null
}
if (Test-Path $logFile) {
  Remove-Item $logFile
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" `
    -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 4)
Register-ScheduledTask -TaskName $taskName -Action $action `
    -Principal $principal -Settings $settings -Force | Out-Null

try {
  echo "`nInstalling Windows updates.  This can take a long time...`n"
  Start-ScheduledTask -TaskName $taskName

  # Wait for the task to finish.  Sleep first, so the task has time to start.
  $waited = 0
  do {
    Start-Sleep -Seconds 10
    $waited += 10
    if ($waited % 300 -eq 0) {
      echo "Still installing updates after $($waited / 60) minutes..."
    }
    $state = (Get-ScheduledTask -TaskName $taskName).State
  } while ($state -eq "Running" -or $state -eq "Queued")

  $result = (Get-ScheduledTaskInfo -TaskName $taskName).LastTaskResult

  if (Test-Path $logFile) {
    Get-Content $logFile
  }
} finally {
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Exit with 3010 if a restart is needed, so that shaka-lab-update-os and the
# package install script know.  Exit with 0 otherwise, so that an earlier
# command's code isn't left behind.
if ($result -eq 3010) {
  echo "`n*** Restart this computer to finish installing updates. ***`n"
  exit 3010
} elseif ($result -ne 0) {
  throw "Installing Windows updates failed with code $result.  See $logFile"
} else {
  echo "`nWindows updates are installed.`n"
  exit 0
}
