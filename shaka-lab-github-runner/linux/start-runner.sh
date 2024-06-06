#!/bin/bash

# Copyright 2023 Google LLC
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

# Fail on error
set -e 

PREFIX="shaka-lab-github-runner"
INSTANCE="$1"
HOSTNAME=$(hostname)

function is_number() {
  # An easy way to check if a variable contains a number is using [ ] and -eq.
  # If [ "$X" -eq "$X" ], then $X contains a number.
  # Typically, [[ ]] is recommended over [ ], for very good reasons.  But you
  # can only use this numeric equality trick with [ ].  With [[ ]], -eq behaves
  # differently.
  local ARG="$1"
  if [ "$ARG" -eq "$ARG" ] &>/dev/null; then
    return 0  # Success: it is a number
  else
    return 1  # Failure: it isn't a number
  fi
}

if is_number "$INSTANCE"; then
  # It's a number!
  true
else
  echo "You must pass an instance number." 1>&2
  exit 1
fi

# Runner name shown on GitHub.  The instance number is 0-padded to 3 digits.
RUNNER_NAME="$HOSTNAME-$(printf %03d $INSTANCE)"
# Container name shown locally in Docker.  Same padding.
CONTAINER_NAME="$PREFIX-$(printf %03d $INSTANCE)"
# The Docker image we run.
# This is from https://github.com/myoung34/docker-github-actions-runner
DOCKER_IMAGE="myoung34/github-runner:latest"

# It's okay if these cleanup commands fail.  The container may not exist if
# cleanup was successful last time.
docker stop "$CONTAINER_NAME" || true
docker rm "$CONTAINER_NAME" || true

# Collect extra docker arguments that are computed by this startup script.
extra_docker_args=()

# Expand * to an empty set if the directory is empty.
shopt -s nullglob

# These globs, if they exist, contain environment variables that should apply
# to this instance.
for i in /etc/shaka-lab-github-runner.env \
         /etc/shaka-lab-github-runner.env.d/* \
         /etc/shaka-lab-github-runner@"$INSTANCE".env.d/*; do
  extra_docker_args+=(--env-file "$i")
done

# These globs, if they exist, contain docker arguments that should apply to
# this instance.
for i in /etc/shaka-lab-github-runner.args.d/* \
         /etc/shaka-lab-github-runner@"$INSTANCE".args.d/*; do
  extra_docker_args+=($(cat "$i"))
done

# If shaka-lab-cert-{generator,receiver} is installed, make those certificates
# available to the runner as a read-only bind mount.  That package already sets
# ownership such that the runner user in the docker image can read the files.
if dpkg -s shaka-lab-cert-generator &>/dev/null || \
    dpkg -s shaka-lab-cert-receiver &>/dev/null; then
  extra_docker_args+=(--mount type=bind,src=/etc/letsencrypt,dst=/etc/letsencrypt,ro)
fi

# Start a docker container.
#   --rm: Remove the container when it shuts down.
#   --name: The name of the container.
#   --network host: Use the host directly for networking, rather than NAT.
#   --pull always: Always use the most up-to-date docker image.
#   -e ALLOCATED_PORT=...: A port number allocated to this instance.  Not every
#                          workflow needs this, but Shaka Player does.
#   -e RUNNER_NAME=...: The runner name, which shows up on GitHub Actions.
#   -e RUNNER_WORKDIR=...: The runner working directory, inside the container.
#   -e DISABLE_AUTO_UPDATE=1: Disable the runner software's self-update.
#   -e EPHEMERAL=1: Force the runner to shut down between jobs.
docker run \
  --rm \
  --name "$CONTAINER_NAME" \
  --network host \
  --pull always \
  -e ALLOCATED_PORT=$(( 61700 + $INSTANCE )) \
  -e RUNNER_NAME="$RUNNER_NAME" \
  -e RUNNER_WORKDIR=/tmp/runner/work \
  -e DISABLE_AUTO_UPDATE=1 \
  -e EPHEMERAL=1 \
  "${extra_docker_args[@]}" \
  "$DOCKER_IMAGE"
