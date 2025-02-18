#!/bin/bash

# Copyright 2025 Google LLC
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

# Update to the latest Node LTS through NVM.

# Fail on error.
set -e

if [[ "$EUID" != 0 ]]; then
  echo "Must be run as root!" 1>&2
  exit 1
fi

# Load NVM.
export NVM_DIR=/opt/shaka-lab/nvm
. "$NVM_DIR/nvm.sh"

nvm install --lts
nvm alias default 'lts/*'
