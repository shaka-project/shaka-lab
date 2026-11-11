#!/bin/sh

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

# Stand-in for matter-power-control in tests. Echoes its arguments, then
# behaves according to the label:
#   fail  exits 1 with a Python-style traceback, like the real tool
#   slow  takes 0.3 seconds
# If FAKE_POWER_LOG is set, start and end lines are appended to it.

label=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "--label" ]; then label="$arg"; fi
  prev="$arg"
done

[ -n "$FAKE_POWER_LOG" ] && echo "start $label" >> "$FAKE_POWER_LOG"
echo "args: $*"

case "$label" in
  fail)
    echo "Traceback (most recent call last):" >&2
    echo "RuntimeError: Failed to power off." >&2
    exit 1
    ;;
  slow)
    sleep 0.3
    ;;
esac

[ -n "$FAKE_POWER_LOG" ] && echo "end $label" >> "$FAKE_POWER_LOG"
exit 0
