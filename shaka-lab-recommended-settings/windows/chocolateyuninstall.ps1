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

# Runs on uninstall.

# Stop on all errors
$ErrorActionPreference = "Stop"

# Chocolatey doesn't remove shims made with Install-BinFile by itself.
Uninstall-BinFile -Name shaka-lab-update-os

# Remove the block that installation added to the all-users PowerShell profile.
# Delete the file if nothing else is left in it, since it doesn't exist by
# default.
$profilePath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\profile.ps1"
$blockStart = "# BEGIN shaka-lab-recommended-settings"
$blockEnd = "# END shaka-lab-recommended-settings"
if (Test-Path $profilePath) {
  $lines = @(Get-Content $profilePath)
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
    Remove-Item $profilePath
  } elseif ($newLines.Count -ne $lines.Count) {
    # Windows PowerShell reads a script without a byte order mark in the
    # system's legacy code page, so write UTF-8 with one.
    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllLines($profilePath, [string[]]$newLines, $utf8WithBom)
  }
}
