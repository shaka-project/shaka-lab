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
#  - Disable SSH keys shared across all admin accounts
if (-Not (Test-Path c:\ProgramData\ssh\sshd_config.orig)) {
  cp c:\ProgramData\ssh\sshd_config c:\ProgramData\ssh\sshd_config.orig
}
cp c:\ProgramData\ssh\sshd_config c:\ProgramData\ssh\sshd_config.bk
cat c:\ProgramData\ssh\sshd_config.bk | `
    ? {-Not $_.Contains("administrators_authorized_keys")} | `
    Set-Content c:\ProgramData\ssh\sshd_config


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


echo "`nConfiguring Windows Update...`n"
#  - No updates between midnight at 6pm local
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name ActiveHoursStart -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name ActiveHoursEnd -Value 18
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name UserChoiceActiveHoursStart -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name UserChoiceActiveHoursEnd -Value 18
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name SmartActiveHoursState -Value 0
#  - Restart without prompting the logged-in user
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name RestartNotificationsAllowed2 -Value 0


echo "`nInstalling all Windows and driver updates now...`n"
Install-PackageProvider -Name NuGet -Scope CurrentUser -Force | Out-Null
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
Install-Module PSWindowsUpdate -Scope CurrentUser
# NOTE: Needs admin rights
Install-WindowsUpdate -Confirm:$false

