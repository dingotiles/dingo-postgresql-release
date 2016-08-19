#!/bin/bash

set -e

NOTES=$PWD/release-notes

version=$(cat version/number)

echo v${version} > $NOTES/release-name

cat > $NOTES/notes.md <<EOF
## Improvements

TODO

## Upload to BOSH

To upload BOSH releases:

\`\`\`
curl -s "https://api.github.com/repos/dingotiles/dingo-postgresql-release/releases/tags/v${version}" | jq -r ".assets[].browser_download_url"  | grep tgz | \
  xargs -L1 bosh upload release --skip-if-exists
\`\`\`

Or get URLs for BOSH releases:

\`\`\`
curl -s "https://api.github.com/repos/dingotiles/dingo-postgresql-release/releases/tags/v${version}" | jq -r ".assets[].browser_download_url"  | grep tgz
\`\`\`
EOF
