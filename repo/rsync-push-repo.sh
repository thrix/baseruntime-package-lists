#!/usr/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -e

if [ x$1 == x ]; then
    release="test/26_Alpha"
else
    release=$1
fi

if [ x$2 == x ]; then
    dest="$SCRIPT_DIR/$release"
else
    dest="$2/$release"
fi

rsync -avh --delete-before --no-perms --omit-dir-times -e ssh  $dest/ fedorapeople.org:/project/modularity/repos/fedora/$release
