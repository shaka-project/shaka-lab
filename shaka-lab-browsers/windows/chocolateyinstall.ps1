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

# These browser packages are not allowed as "dependencies" in chocolatey for
# some reason.  So we install them each separately in this install script.

choco install -y firefox

# Chrome is downloaded from a URL which is not versioned, so it is not
# possible for the chocolatey package maintainer for googlechrome to keep
# checksums up-to-date.  Therefore we have to use --ignore-checksums.
choco install -y googlechrome --ignore-checksums

choco install -y adb
