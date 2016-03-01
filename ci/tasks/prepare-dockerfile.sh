#!/bin/bash

set -e

cp -r ${dockerfile_root}/ dockerfile/
cp -r patroni dockerfile/
