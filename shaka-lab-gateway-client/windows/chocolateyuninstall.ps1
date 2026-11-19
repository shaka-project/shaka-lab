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

# Runs on uninstall.

# Stop on all errors
$ErrorActionPreference = "Stop"

# Commands to leave the domain will fail if we're not in it, so check.
$domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain

# NOTE: This is a case-insensitive check.
if ($domain -eq "lab.shaka") {
  # Revoke lab admins' admin rights.  This must happen before leaving the
  # domain, while the name LAB\labadmins can still be resolved.  S-1-5-32-544
  # is the local Administrators group, whatever its name in the system's
  # language.
  $revoked = $false
  try {
    Remove-LocalGroupMember -SID S-1-5-32-544 -Member "LAB\labadmins"
    $revoked = $true
    echo "`nRevoked admin rights from LAB\labadmins.`n"
  } catch [Microsoft.PowerShell.Commands.MemberNotFoundException] {
    echo "`nLAB\labadmins did not have admin rights.`n"
  }

  echo "`nLeaving the Shaka Lab domain via Shaka Lab Gateway.`n"
  echo "`nWhen prompted, enter your Active Directory Administrator password.`n"
  try {
    Remove-Computer -UnjoinDomainCredential Administrator -Force
  } catch {
    # If leaving fails (for example, a mistyped password), Windows rolls back
    # and the computer stays in the domain.  Give lab admins their rights back,
    # so that a failed uninstall leaves the computer as it was.
    if ($revoked) {
      Add-LocalGroupMember -SID S-1-5-32-544 -Member "LAB\labadmins"
      echo "`nFailed to leave the domain.  Restored admin rights to LAB\labadmins.`n"
    }
    throw
  }
  echo "`nSuccessfully left the Shaka Lab domain.`n"
  echo "`n*** Restart this computer to finish leaving the Shaka Lab domain. ***`n"
} else {
  echo "`nAlready left the Shaka Lab domain.`n"
}

# Let Windows register this machine's addresses in DNS again, as it does by
# default.  Tolerate the setting already being gone.
Remove-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters `
    -Name DisableDynamicUpdate -ErrorAction SilentlyContinue

# Remove the SSH client settings block that installation added.  Delete the
# file if nothing else is left in it, since it doesn't exist by default.
$sshConfig = "$env:ProgramData\ssh\ssh_config"
$blockStart = "# BEGIN shaka-lab-gateway-client"
$blockEnd = "# END shaka-lab-gateway-client"
if (Test-Path $sshConfig) {
  $lines = @(Get-Content $sshConfig)
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

  if (@($newLines | ? { $_.Trim() -ne "" }).Count -eq 0) {
    echo "`nRemoving SSH client settings for lab hosts...`n"
    Remove-Item $sshConfig
  } elseif ($newLines.Count -ne $lines.Count) {
    echo "`nRemoving SSH client settings for lab hosts...`n"
    # WriteAllLines writes UTF-8 without a byte order mark.
    [System.IO.File]::WriteAllLines($sshConfig, [string[]]$newLines)
  }
}
