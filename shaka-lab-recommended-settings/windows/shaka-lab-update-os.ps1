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

# Installs all package and OS updates: Chocolatey packages, then Windows and
# driver updates.  Needs admin rights.  This works over SSH.
#
# The shaka-lab-recommended-settings package puts this on the PATH as the
# command shaka-lab-update-os, for admins to run by hand.
#
# Usage: shaka-lab-update-os [--restart]
#
# Without --restart, this never restarts the computer.  If a restart is needed
# to finish installing updates, it says so and exits with code 3010, the usual
# Windows code for that.  With --restart, it restarts the computer if one is
# needed.


# Stop on all errors
$ErrorActionPreference = "Stop"

# There's no param block, because the flag is spelled the same as on Linux and
# macOS, and PowerShell doesn't parse flags that start with two dashes.
$restart = $false
if ($args.Count -eq 1 -and $args[0] -eq "--restart") {
  $restart = $true
} elseif ($args.Count -ne 0) {
  # Write-Error would wrap this in a PowerShell error record.
  [Console]::Error.WriteLine("Usage: shaka-lab-update-os [--restart]")
  exit 2
}

$restartNeeded = $false
$packagesFailed = $false

# Chocolatey passes package exit codes through.  It counts 0, 1605, 1614, 1641,
# and 3010 as success, and 1641 and 3010 mean a package needs a restart.  Other
# codes mean something failed.
#
# One package that can't be upgraded shouldn't hold back other packages or
# Windows updates.  So a failure is reported, and the script goes on, and
# exits with code 1 at the end.
function Check-ChocoResult {
  if ($LASTEXITCODE -eq 3010 -or $LASTEXITCODE -eq 1641) {
    $script:restartNeeded = $true
  } elseif (@(0, 1605, 1614) -notcontains $LASTEXITCODE) {
    $script:packagesFailed = $true
    echo "`n*** Upgrading Chocolatey packages failed with code $LASTEXITCODE. ***`n"
  }
}

function Report-PackageFailure {
  echo "`n*** Some Chocolatey packages failed to upgrade.  See the errors above. ***`n"
}


# shaka-lab-node keeps Java and Node.js running.  Stop it while packages are
# upgraded, so that their files aren't in use, and start it again afterwards.
$nodeService = Get-Service -Name shaka-lab-node -ErrorAction SilentlyContinue
$nodeWasRunning = $nodeService -and $nodeService.Status -eq "Running"
if ($nodeWasRunning) {
  echo "`nStopping shaka-lab-node while packages are upgraded...`n"
  Stop-Service -Name shaka-lab-node
}

try {
  echo "`nUpgrading Chocolatey packages...`n"

  # These packages run MSI installers quietly without /norestart, so if their
  # files are in use, the installer restarts the computer without asking.  Pass
  # /norestart, so that the installer exits with 3010 instead.  Upgrade them
  # first, because upgrading shaka-lab-node starts it again.  Skip the ones
  # that aren't installed, because "choco upgrade" would install them.
  $noRestartPackages = @(
      @("microsoft-openjdk", "nodejs-lts", "nodejs.install", "nodejs") |
      ? { Test-Path "$env:ChocolateyInstall\lib\$_" })
  if ($noRestartPackages.Count -gt 0) {
    # PowerShell passes each item in the array as a separate argument.
    choco upgrade $noRestartPackages -y --install-arguments="/norestart"
    Check-ChocoResult
  }

  # Google Chrome downloads from a URL that isn't versioned, so its package
  # can't keep its checksums current.  Upgrade everything else with checksums
  # checked, then Chrome on its own without them, as shaka-lab-browsers
  # installs it.
  choco upgrade all -y `
      --except="googlechrome,microsoft-openjdk,nodejs-lts,nodejs.install,nodejs"
  Check-ChocoResult
  if (Test-Path "$env:ChocolateyInstall\lib\googlechrome") {
    choco upgrade googlechrome -y --ignore-checksums
    Check-ChocoResult
  }

  # Chocolatey's exit code covers many packages, and a later package's 3010
  # can hide an earlier failure.  A package that failed is still outdated, so
  # check for those too.  Each line is "name|current|available|pinned", and
  # pinned packages are skipped.  A version released during this run also
  # shows up here, and running this again clears it.
  $stillOutdated = @(choco outdated --limit-output |
      ? { $_ -match '^[^|]+\|[^|]*\|[^|]*\|false$' } |
      % { ($_ -split '\|')[0] })
  if ($stillOutdated.Count -gt 0) {
    $packagesFailed = $true
    echo "`n*** Still outdated after upgrading: $($stillOutdated -join ', ') ***"
    echo "*** Either they failed, or a newer version was just released. ***`n"
  }
} finally {
  # Upgrading shaka-lab-node replaces the service and starts it, so check that
  # it still exists and isn't already running.
  $nodeService = Get-Service -Name shaka-lab-node -ErrorAction SilentlyContinue
  if ($nodeWasRunning -and $nodeService -and
      $nodeService.Status -ne "Running") {
    echo "`nStarting shaka-lab-node again...`n"
    Start-Service -Name shaka-lab-node
  }
}


# Windows Update needs a separate script, which runs the updates as SYSTEM in a
# scheduled task, because Windows refuses to install updates from SSH sessions.
# It exits with 3010 if Windows Update says a restart is needed.
$packageFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
& "$packageFolder\install-windows-updates.ps1"
if ($LASTEXITCODE -eq 3010) {
  $restartNeeded = $true
}


# Windows Update and other installers also leave these behind when a restart
# is needed to finish.
$restartKeys = @(
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
)
foreach ($key in $restartKeys) {
  if (Test-Path $key) {
    $restartNeeded = $true
  }
}

# Don't restart if a package failed.  A failed upgrade can leave a package that
# shaka-lab-node needs unable to start, and then it wouldn't come back after
# the restart.
if ($restartNeeded -and $restart -and $packagesFailed) {
  echo "`nNot restarting, because a package failed.  Fix it first, then run"
  echo "shaka-lab-update-os --restart again."
  $restart = $false
}

if ($restartNeeded -and $restart) {
  echo "`nRestarting this computer to finish installing updates...`n"
  Restart-Computer -Force
  exit 0
}

if ($restartNeeded) {
  echo "`n*** Restart this computer to finish installing updates. ***"
  if ($packagesFailed) {
    echo "*** Fix the failed packages, then to restart, run: ***"
    echo "***   shaka-lab-update-os --restart ***`n"
  } else {
    echo "*** To restart now, run: shaka-lab-update-os --restart ***`n"
  }
}

# A failure takes priority over a needed restart, so that a failure is never
# mistaken for success.
if ($packagesFailed) {
  Report-PackageFailure
  exit 1
}

if ($restartNeeded) {
  exit 3010
}

echo "`nUpdates are installed.`n"
