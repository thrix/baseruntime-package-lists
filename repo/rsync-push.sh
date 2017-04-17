#!/usr/bin/bash

set -e

if [ x$1 == x ]; then
    release="test/26_Alpha"
else
    release=$1
fi

# Make sure every directory is present, even if it is empty
for arch in "x86_64" "i686" "armv7hl" "aarch64" "ppc64" "ppc64le"; do
    mkdir -p $release/$arch/sources $release/$arch/os
    createrepo_c $release/$arch/sources
    createrepo_c $release/$arch/os
done

# Set the group ownership to the modularity-wg group
chgrp -R 189842 $release

# Any changes made in these directories should also set this group
find $release -type d -exec chmod g+s {} \;

rsync -avh --delete-before -e ssh  $release/ fedorapeople.org:/project/modularity/repos/fedora/gencore-override/$release
