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

# A certbot deploy hook, installed by shaka-lab-github-runner into
# /etc/letsencrypt/renewal-hooks/deploy/.  It makes certificates and keys
# readable by the runner user inside the GitHub Actions Runner docker image.
# The runner's start script mounts /etc/letsencrypt/{live,archive} into the
# container read-only.
#
# This is also run by the package's postinst script, so that certificates
# issued before the package was installed are readable, too.

# Fail on error
set -e

# Expand * to an empty set if there are no matches.
shopt -s nullglob

# The exact GID of the "runner" group in the Docker image we use for the GitHub
# Actions Runner.  This doesn't need to exist as a named group on the host.
RUNNER_GID=121

# Nothing to do if certbot hasn't issued anything yet.
if [[ ! -d /etc/letsencrypt/live || ! -d /etc/letsencrypt/archive ]]; then
  exit 0
fi

# Certbot creates these as 700.  Make them world-traversable.
chmod 755 /etc/letsencrypt/{archive,live}

# The real files live in archive/; live/ only has symlinks to them.  Make certs
# world-readable, and private keys readable by the runner group.
for file in /etc/letsencrypt/archive/*/*; do
  chown root:"$RUNNER_GID" "$file"
  case "$(basename "$file")" in
    privkey*) chmod 640 "$file" ;;
    *) chmod 644 "$file" ;;
  esac
done
