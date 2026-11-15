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
# A join only takes effect after a restart.  Until then, Windows may still
# report the old domain, but it keeps the Netlogon\JoinDomain registry key
# while the join is pending.
$domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
$joinPending = Test-Path HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\JoinDomain
$restartNeeded = $false

# NOTE: This is a case-insensitive check.
if ($domain -eq "lab.shaka" -and -Not $joinPending) {
  echo "`nAlready a member of the Shaka Lab domain.`n"
} elseif ($joinPending) {
  echo "`nAlready joined the Shaka Lab domain, but a restart is still needed.`n"
  $restartNeeded = $true
} else {
  # Kerberos rejects clock skew over 5 minutes, so sync the clock before
  # joining.  shaka-lab-recommended-settings sets up ongoing time sync.
  echo "`nSyncing the clock...`n"
  Start-Service -Name w32time
  w32tm /resync /rediscover

  echo "`nJoining Shaka Lab domain via Shaka Lab Gateway.`n"
  echo "`nWhen prompted, enter your Active Directory Administrator password.`n"
  Add-Computer -DomainName LAB.SHAKA -Credential Administrator
  echo "`nSuccessfully joined the Shaka Lab domain!`n"
  $restartNeeded = $true
}


# Give lab admins admin rights on this machine.  S-1-5-32-544 is the local
# Administrators group, whatever its name in the system's language.
try {
  Add-LocalGroupMember -SID S-1-5-32-544 -Member "LAB\labadmins"
  echo "`nGave LAB\labadmins admin rights.`n"
} catch [Microsoft.PowerShell.Commands.MemberExistsException] {
  echo "`nLAB\labadmins already has admin rights.`n"
} catch [Microsoft.PowerShell.Commands.PrincipalNotFoundException] {
  # Right after joining, the domain's groups may not resolve until a restart.
  Write-Warning ("Could not find LAB\labadmins.  " +
      "After restarting, install this package again to give lab admins " +
      "admin rights.")
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
$newLines = @($lines | ? {
  ($_ -notmatch '^\s*Match\s+Group\s+administrators\s*$') -and
  (-Not $_.Contains("administrators_authorized_keys"))
})

# For the same S4U reason, SSH keys don't work for domain users.  Kerberos
# (GSSAPI) logins do: the client presents a Kerberos ticket for this host, and
# Windows builds the user's token from that ticket without S4U.  Turn that on
# by replacing the stock "#GSSAPIAuthentication no" line.  If there is no such
# line, append one.  That is safe because no Match block remains to capture it.
$newLines = @($newLines | % {
  if ($_ -match '^\s*#?\s*GSSAPIAuthentication\s') {
    "GSSAPIAuthentication yes"
  } else {
    $_
  }
})
if (-Not ($newLines -contains "GSSAPIAuthentication yes")) {
  $newLines += "GSSAPIAuthentication yes"
}

if (($newLines -join "`n") -ne ($lines -join "`n")) {
  echo "`nConfiguring SSH server for domain users...`n"
  # WriteAllLines writes UTF-8 without a byte order mark, which sshd requires.
  [System.IO.File]::WriteAllLines($sshdConfig, [string[]]$newLines)
  Restart-Service -Name sshd
}


# Configure the SSH client, so that domain users can log in to other lab
# machines with the Kerberos ticket from their Windows login:
#
#  - Windows' ssh client sends a domain user's name as "lab\USER", which other
#    lab machines don't recognize.  The USERNAME environment variable holds the
#    name without the domain.
#  - Kerberos (GSSAPI) logins are off by default in Windows' ssh client.
#  - Delegating credentials forwards the Kerberos ticket, so that further SSH
#    hops don't need a password or kinit.  Windows only forwards a ticket to a
#    host that is trusted for delegation in Active Directory.
#
# These settings live in a marked block that this package owns, and that
# uninstalling removes.  Settings in a user's own .ssh\config take precedence.
$sshConfig = "$env:ProgramData\ssh\ssh_config"
$blockStart = "# BEGIN shaka-lab-gateway-client"
$blockEnd = "# END shaka-lab-gateway-client"
$block = @(
  $blockStart,
  # Match the lab hosts the same way the Linux package does, including short
  # names like "shaka-linux2".
  'Host *.lab.shaka shaka-* gateway',
  '    User ${USERNAME}',
  '    GSSAPIAuthentication yes',
  '    GSSAPIDelegateCredentials yes',
  $blockEnd
)

$lines = @()
if (Test-Path $sshConfig) {
  $lines = @(Get-Content $sshConfig)
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
  echo "`nConfiguring SSH client for lab hosts...`n"
  # WriteAllLines writes UTF-8 without a byte order mark.
  [System.IO.File]::WriteAllLines($sshConfig, [string[]]$newLines)
}


if ($restartNeeded) {
  echo "`n*** Restart this computer to finish joining the Shaka Lab domain. ***`n"
}
