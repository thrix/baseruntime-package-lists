#!/usr/bin/bash

set -e

if [ x$1 == x ]; then
    release="test/26_Alpha"
else
    release=$1
fi

for arch in "x86_64" "i686" "armv7hl" "aarch64" "ppc64" "ppc64le" "s390x"; do
    mkdir -p repo/$release/$arch/sources/
    mv output/$arch/*.src.rpm repo/$release/$arch/sources/
done
