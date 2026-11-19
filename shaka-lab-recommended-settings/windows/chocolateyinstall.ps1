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


# Stop on all errors
$ErrorActionPreference = "Stop"


# Each of the echo commands below uses `n (powershell newline character) to
# start a new line for its status output.  That is because choco install has a
# progress meter that would otherwise conflict with these status messages.


echo "`nInstalling and starting SSH server...`n"
Add-WindowsCapability -Online -Name OpenSSH.Server | Out-Null
Set-Service -Name "sshd" -Status running -StartupType automatic


echo "`nConfiguring SSH server`n"
#  - Use PowerShell as the login shell
New-ItemProperty `
  -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
  -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
  -PropertyType String -Force | Out-Null


echo "`nConfiguring PowerShell...`n"
# Let PowerShell run local scripts, including the all-users profile below.
# Scripts downloaded from the internet still need a signature.  The Windows
# default, Restricted, runs no scripts at all, not even profiles.
#
# Chocolatey runs this script with "-ExecutionPolicy Bypass", which sets the
# policy for this process only.  Set-ExecutionPolicy saves the machine-wide
# policy, then reports an error because this process's policy overrides it.
# Ignore that error, as long as the machine-wide policy was saved.
try {
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
} catch {
  if ((Get-ExecutionPolicy -Scope LocalMachine) -ne "RemoteSigned") {
    throw
  }
}

# The Microsoft JDK, which shaka-lab-node depends on, puts its bin folder at
# the front of the system PATH on every install and upgrade.  The JDK has its
# own klist.exe, which hides Windows' klist, the one that shows a domain user's
# Kerberos tickets.  In PowerShell, an alias takes precedence over PATH, so
# define one in the all-users profile.  This also covers SSH sessions, since
# PowerShell is the SSH login shell.
#
# The alias lives in a marked block that this package owns, and that
# uninstalling removes.
$profilePath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\profile.ps1"
$blockStart = "# BEGIN shaka-lab-recommended-settings"
$blockEnd = "# END shaka-lab-recommended-settings"
$block = @(
  $blockStart,
  "# Use Windows' klist, not the JDK's, which comes first in PATH.",
  'Set-Alias -Name klist -Value "$env:SystemRoot\System32\klist.exe"',
  $blockEnd
)

$lines = @()
if (Test-Path $profilePath) {
  $lines = @(Get-Content $profilePath)
}

# Drop any copy of the block from an earlier install, then append the current
# one.
$newLines = @()
$inBlock = $false
foreach ($line in $lines) {
  if ($line -eq $blockStart) {
    $inBlock = $true
  }
  if (-Not $inBlock) {
    $newLines += $line
  }
  if ($line -eq $blockEnd) {
    $inBlock = $false
  }
}
$newLines += $block

if (($newLines -join "`n") -ne ($lines -join "`n")) {
  # Windows PowerShell reads a script without a byte order mark in the
  # system's legacy code page, so write UTF-8 with one.
  $utf8WithBom = New-Object System.Text.UTF8Encoding $true
  [System.IO.File]::WriteAllLines($profilePath, [string[]]$newLines, $utf8WithBom)
}


echo "`nEnabling time sync...`n"
# Domain members normally sync time from a domain controller, but the Shaka Lab
# Gateway doesn't serve time.  Always sync from a public time server instead,
# whether or not this machine is in a domain.  The 0x8 flag means an ordinary
# NTP client, using the normal polling interval.
Set-Service -Name w32time -StartupType Automatic
Start-Service -Name w32time
w32tm /config /manualpeerlist:"time.windows.com,0x8" /syncfromflags:manual /update


echo "`nEnabling Remote Desktop connections`n"
# NOTE: Needs admin rights
Set-ItemProperty `
    -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
    -name "fDenyTSConnections" -value 0


echo "`nDisabling firewall...`n"
Set-NetFirewallProfile -Enabled False


echo "`nDisabling all forms of sleep and hibernate...`n"
powercfg /X monitor-timeout-ac 0
powercfg /X monitor-timeout-dc 0
powercfg /X disk-timeout-ac 0
powercfg /X disk-timeout-dc 0
powercfg /X standby-timeout-ac 0
powercfg /X standby-timeout-dc 0
powercfg /X hibernate-timeout-ac 0
powercfg /X hibernate-timeout-dc 0


# This step appends to a file, so skip it if the settings are already there.
if (-Not (cat c:\tools\vim\_vimrc | Select-String nobackup -Quiet)) {
  echo "`nConfiguring vim`n"
  # Disable backup files which clutter the filesystem
  Add-Content "c:\tools\vim\_vimrc" "`r`nset nobackup`r`nset noundofile`r`n"
}

# This step also appends, so skip it if the settings are already there.
if (-Not (cat c:\tools\vim\_vimrc | Select-String "Char-0x7f" -SimpleMatch -Quiet)) {
  echo "`nConfiguring vim for SSH sessions`n"
  Add-Content "c:\tools\vim\_vimrc" @(
    "",
    "`" Over SSH, Backspace arrives as a literal DEL (0x7F).  Treat it as Backspace.",
    "if has('win32') && !has('gui_running')",
    "  noremap! <Char-0x7f> <BS>",
    "  nnoremap <Char-0x7f> <BS>",
    "endif",
    "",
    "`" Keep vim from clearing the screen on exit.",
    "set t_ti= t_te="
  )
}


echo "`nConfiguring Windows Update...`n"
#  - No updates between midnight at 6pm local
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name ActiveHoursStart -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name ActiveHoursEnd -Value 18
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name UserChoiceActiveHoursStart -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name UserChoiceActiveHoursEnd -Value 18
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name SmartActiveHoursState -Value 0
#  - Restart without prompting the logged-in user
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name RestartNotificationsAllowed2 -Value 0


echo "`nAdding the shaka-lab-update-os command...`n"
# Admins can run "shaka-lab-update-os" at any time, including over SSH, to
# install all Chocolatey package and Windows updates.  This puts a shim on the
# PATH that runs the script with PowerShell.  Install-BinFile passes -Command
# to the shim generator without quoting it, so the value has to include its own
# quotes.  Without them, the shim starts an interactive PowerShell instead.
$packageFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
Install-BinFile -Name shaka-lab-update-os `
    -Path "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Command "`"-NoProfile -ExecutionPolicy Bypass -File $packageFolder\shaka-lab-update-os.ps1`""
# Older versions called the command shaka-lab-windows-update.
Uninstall-BinFile -Name shaka-lab-windows-update


echo "`nInstalling all Windows and driver updates now...`n"
# Try to install updates, but don't fail this package installation if Windows
# Update fails.  That is out of our control.
try {
  # This script runs the updates as SYSTEM in a scheduled task, which also
  # works over SSH.  Running it in a separate process also avoids a conflict
  # inside Chocolatey scripts, where chocolatey-windowsupdate.extension (also
  # present on lab machines) defines its own Install-WindowsUpdate.
  & "$packageFolder\install-windows-updates.ps1"
  # Chocolatey ignores $LASTEXITCODE from package scripts.  This is how a
  # package tells it a restart is needed.
  if ($LASTEXITCODE -eq 3010) {
    Set-PowerShellExitCode 3010
  }
} catch {
  # Print the caught exception as an error.
  # -ErrorAction 'Continue' changes Write-Error's default behavior of
  # triggering our $ErrorActionPreference setting to stop execution.
  Write-Error $Error[0] -ErrorAction 'Continue'

  # Print advice to the user.
  echo "`nWindows update failed.  Please install updates through the UI.`n"
}
