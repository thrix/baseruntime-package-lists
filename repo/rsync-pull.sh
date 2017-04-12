#!/usr/bin/bash

set -e

if [ x$1 == x ]; then
    release="test/26_Alpha"
else
    release=$1
fi

mkdir -p $release
rsync -avz -e ssh fedorapeople.org:/project/modularity/repos/fedora/gencore-override/$release/ $release
