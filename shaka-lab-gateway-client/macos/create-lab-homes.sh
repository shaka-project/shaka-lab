#!/bin/bash
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

# Create local home directories for members of the Active Directory group
# "labusers".
#
# On Linux, pam_mkhomedir creates a home directory when an AD user first logs
# in.  macOS has no equivalent PAM module.  Only the GUI login window creates
# homes for AD users, so an SSH login would land without one.  Instead, a
# LaunchDaemon runs this script periodically, so new lab users get a home
# within a few minutes of being created on the gateway.
#
# NOTE: createhomedir logs "UUID is NULL!" for AD users and leaves the ACL off
# of ~/Public/Drop Box.  That folder is only used by File Sharing, which lab
# users don't need.

# Don't fail on error.  A problem with one user shouldn't stop the others.

NODE="/Active Directory/LAB/All Domains"

# Members are listed as "LAB\username".  If the domain is unreachable, this
# outputs nothing, and we try again on the next run.
members=$(/usr/bin/dscl "$NODE" -read /Groups/labusers GroupMembership 2>/dev/null |
    /usr/bin/sed -e 's/^GroupMembership://')

for member in $members; do
  user="${member#LAB\\}"

  home=$(/usr/bin/dscl "$NODE" -read "/Users/$user" NFSHomeDirectory 2>/dev/null |
      /usr/bin/awk '{print $2}')

  if [[ -n "$home" && ! -d "$home" ]]; then
    echo "$(date): Creating $home for $user"
    /usr/sbin/createhomedir -c -n "$NODE" -u "$user"
  fi
done
