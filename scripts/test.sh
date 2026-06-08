#!/bin/bash

#####################
# SETUP
#########

# Fail fast
set -e

# Assume PWD is root of the repo
source ./scripts/env.sh

# Make sure the test container is removed
# when the shell exits, in error or not
atExit() {
  info removing test container
  docker rm -f "${containerId}"
}
trap atExit EXIT

#####################
# MAIN
#########

# Get the platform on which the container will be run
architecture=$(uname -m)

if [ "$architecture" = "x86_64" ] || [ "$architecture" = "amd64" ]; then
    platform=amd64
elif [ "$architecture" = "aarch64" ] || [ "$architecture" = "arm64" ] ; then
    platform=arm64
else
    echo "Unsupported platform: $platform"
    exit 1
fi

# Image to test against; can be overridden via TEST_IMAGE env var
test_image="${TEST_IMAGE:-akamai/shell}"

# Based on the platform, choose the correct local image and get the container id
image="${test_image}:local-${platform}"
info starting test container with tag "${image}"
# In case the image is not found, fail rather than pull remote image
containerId=$(docker run -d --name test --pull=never "${image}" sleep 3600)

# Test files to run; can be overridden via TEST_FILES env var (comma-separated)
test_files="${TEST_FILES:-test.bats}"

# Copy each test file to the container and build the bats argument list
bats_args=""
IFS=',' read -ra test_file_list <<< "${test_files}"
for f in "${test_file_list[@]}"; do
  f=$(echo "$f" | xargs)  # trim surrounding whitespace
  docker cp "./${f}" "${containerId}":/"${f##*/}"
  bats_args="${bats_args} /${f##*/}"
done

docker exec -i "${containerId}" bash <<EOF
set -e

apk add --no-cache git bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
cd /
bats ${bats_args}
EOF
