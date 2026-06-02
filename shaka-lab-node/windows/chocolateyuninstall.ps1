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

# Runs on uninstall.

# Stop on all errors.
$ErrorActionPreference = "Stop"

# Remove the obsolete nightly WebDriver update task if a previous version
# installed it.  Driver updates now happen on service startup (including the
# daily restart), so the separate scheduled task is no longer used.
$task = Get-ScheduledTask | Where-Object -FilterScript { $_.TaskName -eq "shaka-lab-node-update" }
if ($task) {
  echo "Removing obsolete WebDriver update task..."
  Unregister-ScheduledTask `
      -TaskName shaka-lab-node-update `
      -Confirm:$false
}
