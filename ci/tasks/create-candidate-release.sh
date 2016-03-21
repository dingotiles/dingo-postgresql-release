#!/bin/bash

set -e # fail fast
set -x # print commands

OUTPUT="$PWD/candidate-release"
VERSION="$(cat version/number)"
RELEASE_NAME=${RELEASE_NAME:-dingo-postgresql}

export IMAGE_BASE_DIR=$(pwd)/images

cd boshrelease

# add back when we want to include embedded images in testflight test
# rake images:cleanout
# rake images:package
# rake jobs:update_spec

bosh -n create release --with-tarball --force --name $RELEASE_NAME --version "$VERSION"
mv dev_releases/$RELEASE_NAME/$RELEASE_NAME-*.tgz "$OUTPUT"
