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

# Runs on upgrade and on uninstall.

# Stop on all errors.
$ErrorActionPreference = 'Stop'

# Remove the service if it already exists.  Note that Remove-Service isn't
# available until PowerShell 6, and we can't guarantee that anything more
# recent than 5.1 is installed.
$service = Get-WmiObject -Class Win32_Service -Filter "Name='shaka-lab-node'"
if ($service) {
  echo "Stopping service..."
  Stop-Service -Name shaka-lab-node
  echo "Deleting service..."
  $service.delete()
}
