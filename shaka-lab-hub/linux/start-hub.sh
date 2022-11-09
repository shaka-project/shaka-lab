#!/bin/bash

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

PORT=4444
HOST=0.0.0.0

[ -r /etc/default/shaka-lab-hub ] && . /etc/default/shaka-lab-hub

cd /opt/shaka-lab/shaka-lab-hub

java \
  -jar selenium-server-standalone-3.141.59.jar \
  -role hub \
  -host "$HOST" \
  -port "$PORT" \
  -throwOnCapabilityNotPresent true \
  -maxSession 1 \
  -timeout 30 \
  -browserTimeout 120 \
  -cleanUpCycle 5000
