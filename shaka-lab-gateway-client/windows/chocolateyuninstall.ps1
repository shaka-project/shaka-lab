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
$computer=(Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem)
$domain=$computer.Domain

# NOTE: This is a case-insensitive check.
if ($domain -eq "lab.shaka") {
  echo "`nLeaving the Shaka Lab domain via Shaka Lab Gateway.`n"
  echo "`nWhen prompted, enter your Active Directory Administrator password.`n"
  Remove-Computer -UnjoinDomainCredential Administrator -Force
  echo "`nSuccessfully left the Shaka Lab domain.`n"
} else {
  echo "`nAlready left the Shaka Lab domain.`n"
}
