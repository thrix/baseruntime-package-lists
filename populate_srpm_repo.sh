#!/usr/bin/bash

set -e

if [ x$1 == x ]; then
    release="test/26_Alpha"
else
    release=$1
fi

for arch in "aarch64" "armv7hl" "i686" "ppc64" "ppc64le" "s390x" "x86_64"; do
    mkdir -p repo/$release/$arch/sources/
    mv -v output/$arch/*.src.rpm repo/$release/$arch/sources/
done
