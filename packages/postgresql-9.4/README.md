# postgresql-9.4 BOSH package

## packaging

The package script is called by BOSH during the compilation phase on a
compilation VM after compiling any dependencies listed in the spec file and
providing them to this script located within `/var/vcap/packages/...`.

## prepare

The package's prepare script is used to download necessary files and prepare the
blobs and sources which this BOSH job depends on. This also acts as
documentation as to the original source of the blobs used for this package.
This script will be called from the release directory's 'prepare blobs' script.

## spec

The spec file is used to declare the package name, array of dependency package
names as well as a list of the blob files required by the package script.

