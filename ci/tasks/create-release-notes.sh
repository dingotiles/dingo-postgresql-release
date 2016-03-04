#!/bin/bash

set -e

NOTES=$PWD/release-notes

version=$(cat final-release/version)

echo v${version} > $NOTES/release-name

cat > $NOTES/notes.md <<EOF
These release notes are intentionally blank.
EOF
