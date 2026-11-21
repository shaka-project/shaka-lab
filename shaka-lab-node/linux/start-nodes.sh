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

# Sets up the environment (NVM, Node.js & Xvfb), then launches the Selenium
# nodes (via start-nodes.js).
#
# NVM and Node.js are installed and updated here, on every service start
# (including the daily restart), rather than in the package's post-install
# script.  If an update fails (for example, with no network), we carry on with
# whatever is already installed, and only fail if there is no usable Node.js.

# The NVM release to use, pinned by tag and by commit.  The commit is checked
# against what the tag points to, so a moved tag can't change what we run.
# Bump both together.
NVM_TAG=v0.41.0
NVM_COMMIT=4e8758a801eea9479b32a904f31093e410ddaba4
NVM_REPO=https://github.com/nvm-sh/nvm.git

# The Node.js major version to use.  Bump this by hand.  Node.js 26 reaches
# end-of-life on 2029-04-30.
export NODE_MAJOR=26

# The location of our hermetic NVM installation.
export NVM_DIR=/opt/shaka-lab/nvm

# How long to let each network step run before giving up on it, so that a
# server that never answers can't wedge the service on startup.  Together,
# these cap the startup delay at 5 minutes when the network is down.  The NVM
# fetch is a single shallow tag, and the Node.js install is a ~30MB download,
# so both normally take seconds.
NVM_UPDATE_TIMEOUT=1m
NODE_UPDATE_TIMEOUT=4m

function warn() {
  echo "WARNING: $*" 1>&2
}

# Check out the pinned NVM commit, if it isn't checked out already.  This
# handles fresh installs, older git-based installs, and older script-based
# installs (which have no .git folder) the same way.
function update_nvm() {
  local current
  current=$(git -C "$NVM_DIR" rev-parse --verify --quiet HEAD 2>/dev/null)
  if [[ "$current" == "$NVM_COMMIT" ]]; then
    return 0
  fi

  echo "Installing NVM $NVM_TAG"

  if [[ ! -d "$NVM_DIR/.git" ]]; then
    git -C "$NVM_DIR" init --quiet || return 1
  fi

  timeout "$NVM_UPDATE_TIMEOUT" \
      git -C "$NVM_DIR" fetch --quiet --depth=1 \
      "$NVM_REPO" "refs/tags/$NVM_TAG" || return 1

  local fetched
  fetched=$(git -C "$NVM_DIR" rev-parse --verify --quiet 'FETCH_HEAD^{commit}')
  if [[ "$fetched" != "$NVM_COMMIT" ]]; then
    warn "NVM $NVM_TAG is commit $fetched, but we expected $NVM_COMMIT!"
    return 1
  fi

  git -C "$NVM_DIR" -c advice.detachedHead=false \
      checkout --quiet --force "$NVM_COMMIT"
}

# Install the latest release of our pinned Node.js major version, make it the
# default, and remove every other version.
function update_node() {
  # nvm is a shell function, so to put a timeout on it, it has to run in a new
  # shell.
  if ! timeout "$NODE_UPDATE_TIMEOUT" bash -c \
      '. "$NVM_DIR/nvm.sh" && nvm install "$NODE_MAJOR"'; then
    warn "Failed to install the latest Node.js $NODE_MAJOR."
  fi

  if ! nvm version "$NODE_MAJOR" &>/dev/null; then
    warn "Node.js $NODE_MAJOR is not installed." \
         "Continuing with the existing default."
    return
  fi

  nvm alias default "$NODE_MAJOR"
  nvm use default

  # Clean up every version other than the default.  This only happens once the
  # pinned version is installed, so we never remove the only working version.
  local default version_dir version
  default=$(nvm version default)
  for version_dir in "$NVM_DIR"/versions/node/v*; do
    [[ -d "$version_dir" ]] || continue
    version=$(basename "$version_dir")
    if [[ "$version" != "$default" ]]; then
      nvm uninstall "$version"
    fi
  done
  nvm cache clear
}

if ! update_nvm; then
  warn "Failed to install NVM $NVM_TAG." \
       "Continuing with the installed version, if any."
fi

if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  echo "NVM is not installed!" 1>&2
  exit 1
fi

# Load NVM so we can use our hermetic copy of nodejs.
. "$NVM_DIR/nvm.sh"

update_node

if ! command -v node &>/dev/null; then
  echo "Node.js is not installed!" 1>&2
  exit 1
fi

# Launch Selenium nodes in a headless X session.
xvfb-run -a node /opt/shaka-lab/shaka-lab-node/start-nodes.js
