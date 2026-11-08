# Copyright 2023 Google LLC
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


# Commands to join the domain will fail if we're already in it, so check.
$computer=(Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem)
$domain=$computer.Domain

# NOTE: This is a case-insensitive check.
if ($domain -eq "lab.shaka") {
  echo "`nAlready a member of the Shaka Lab domain.`n"
} else {
  echo "`nJoining Shaka Lab domain via Shaka Lab Gateway.`n"
  echo "`nWhen prompted, enter your Active Directory Administrator password.`n"
  Add-Computer -DomainName LAB.SHAKA -Credential Administrator
  echo "`nSuccessfully joined the Shaka Lab domain!`n"
}


# Lab users must always be able to log in over SSH.  The SSH server is also
# installed by shaka-lab-recommended-settings, but that may not be installed
# yet.  Starting the server for the first time creates sshd_config.
if (-Not (Get-Service -Name sshd -ErrorAction SilentlyContinue)) {
  echo "`nInstalling SSH server...`n"
  Add-WindowsCapability -Online -Name OpenSSH.Server | Out-Null
}
Set-Service -Name sshd -Status running -StartupType automatic


# The stock sshd_config ends with this block:
#
#   Match Group administrators
#          AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
#
# It causes two problems in the lab:
#
#  - Any "Match Group" block makes sshd look up each user's groups before
#    authenticating them.  For a domain user, Windows does that with a
#    passwordless (S4U) Kerberos logon, which doesn't work with the Samba
#    domain controller on the gateway.  sshd then drops the connection, so even
#    password logins fail.
#  - It makes every admin account share one authorized_keys file.
#
# Remove both lines of that block.  This does nothing if they are already gone.
$sshdConfig = "$env:ProgramData\ssh\sshd_config"
$lines = @(Get-Content $sshdConfig)
$kept = @($lines | ? {
  ($_ -notmatch '^\s*Match\s+Group\s+administrators\s*$') -and
  (-Not $_.Contains("administrators_authorized_keys"))
})

if ($kept.Count -ne $lines.Count) {
  echo "`nConfiguring SSH server for domain users...`n"
  # WriteAllLines writes UTF-8 without a byte order mark, which sshd requires.
  [System.IO.File]::WriteAllLines($sshdConfig, [string[]]$kept)
  Restart-Service -Name sshd
}
