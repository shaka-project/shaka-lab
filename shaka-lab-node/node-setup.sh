# shellcheck shell=bash
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

# Installs and updates NVM and Node.js for Shaka Lab Node, on Linux and macOS.
#
# This file is sourced, not run.  Callers export NVM_DIR, the location of their
# hermetic NVM installation, before sourcing it, then call setup_node.
#
# NVM and Node.js are installed and updated on every service start (including
# the daily restart), rather than in the package's install scripts.  If an
# update fails (for example, with no network), we carry on with whatever is
# already installed, and only fail if there is no usable Node.js.
#
# This has to work in the bash that ships with macOS, which is version 3.2.

# The NVM release to use, pinned by tag and by commit.  The commit is checked
# against what the tag points to, so a moved tag can't change what we run.
# Bump both together.
NVM_TAG=v0.41.0
NVM_COMMIT=4e8758a801eea9479b32a904f31093e410ddaba4
NVM_REPO=https://github.com/nvm-sh/nvm.git

# The Node.js major version to use.  Bump this by hand.  Node.js 26 reaches
# end-of-life on 2029-04-30.  nodejs.org builds no Intel Mac binaries for
# Node.js 27, so on Intel Macs, 26 is the last version available.
export NODE_MAJOR=26

# How long, in seconds, to let each network step run before giving up on it,
# so that a server that never answers can't wedge the service on startup.
# Together, these cap the startup delay at 5 minutes when the network is down.
# The NVM fetch is a single shallow tag, and the Node.js install is a ~30MB
# download, so both normally take seconds.
NVM_UPDATE_TIMEOUT=60
NODE_UPDATE_TIMEOUT=240

function warn() {
  echo "WARNING: $*" 1>&2
}

# Run a command, and stop it and everything it started if it runs longer than
# the given number of seconds.  Returns the command's exit status, or 124 if
# it was stopped, like GNU timeout.
function run_with_timeout() {
  local seconds="$1"
  shift

  if command -v timeout &>/dev/null; then
    timeout "$seconds" "$@"
    return
  fi

  # macOS has no timeout command.  In a subshell, turn on job control, so that
  # the command and the watchdog each run in their own process group.  Then
  # the watchdog can stop the whole command, including children such as the
  # curl that NVM runs, and we can stop the whole watchdog, including its
  # sleep.
  (
    set -m
    "$@" &
    local pid=$!
    (sleep "$seconds"; kill -TERM -- "-$pid" 2>/dev/null) &
    local watchdog=$!

    # The command's process group is separate from ours, so stopping ours
    # (for example, stop-services.sh stopping the service) wouldn't reach it.
    # Pass the stop along.
    trap 'kill -TERM -- "-$pid" "-$watchdog" 2>/dev/null; exit 143' TERM INT HUP

    # Hide the shell's own "Terminated" notice.  Callers report the failure.
    wait "$pid" 2>/dev/null
    local status=$?

    # If the watchdog is gone, it fired.
    if ! kill -0 "$watchdog" 2>/dev/null; then
      exit 124
    fi
    kill -TERM -- "-$watchdog" 2>/dev/null
    exit "$status"
  )
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

  run_with_timeout "$NVM_UPDATE_TIMEOUT" \
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
# default, and remove every other version.  NVM must already be loaded.
function update_node() {
  # Clear NVM's cache first.  When the timeout below kills an install, NVM
  # leaves that version's install lock in its cache, and never steals it back
  # by default.  Every later install of that version would then wait on the
  # lock until it timed out, too.  We are the only thing installing Node.js
  # here, so any lock left at this point is stale.  This also drops any
  # partial downloads.
  nvm cache clear

  # nvm is a shell function, so to put a timeout on it, it has to run in a new
  # shell.  Pass -b to install only prebuilt binaries.  If there is no binary
  # for this platform, NVM would otherwise build Node.js from source, which
  # would never finish within the timeout.
  # shellcheck disable=SC2016  # The new shell expands these, not this one.
  if ! run_with_timeout "$NODE_UPDATE_TIMEOUT" bash -c \
      '. "$NVM_DIR/nvm.sh" && nvm install -b "$NODE_MAJOR"'; then
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

# Install or update NVM and Node.js, then load NVM with the default Node.js on
# the PATH.  Returns non-zero if there is no usable Node.js afterward.
function setup_node() {
  if ! update_nvm; then
    warn "Failed to install NVM $NVM_TAG." \
         "Continuing with the installed version, if any."
  fi

  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    echo "NVM is not installed!" 1>&2
    return 1
  fi

  # Load NVM so we can use our hermetic copy of nodejs.
  # shellcheck source=/dev/null  # Installed at runtime, not in this repo.
  . "$NVM_DIR/nvm.sh"

  update_node

  # Only count our own Node.js.  Another one on the PATH, such as Homebrew's on
  # macOS, isn't the version we pinned, and might go away.
  if [[ "$(command -v node)" != "$NVM_DIR"/* ]]; then
    echo "Node.js is not installed!" 1>&2
    return 1
  fi
}
