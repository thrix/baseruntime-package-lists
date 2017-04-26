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

# Pull down the current override repository from fedorapeople
mkdir -p $dest
rsync -avzh --delete-before \
    rsync://fedorapeople.org/project/modularity/repos/fedora/gencore-override/$release/ \
    $dest

# Regenerate the SRPMs for known packages that have arch-specific
# BuildRequires

if [ "$release" == "rawhide" ]; then
    # Get the list of the latest NVRs for these packages
    NVR_FILE=$(mktemp)
    cat ../archful-srpms.txt \
    | xargs koji latest-build rawhide  --quiet \
    | cut -f 1 -d " " \
    > $NVR_FILE

    # Generate the archful SRPMs
    ../mock_wrapper.sh rawhide $NVR_FILE

    # Put the resulting SRPMs into place
    for arch in "x86_64" "i686" "armv7hl" "aarch64" "ppc64" "ppc64le"; do
        mkdir -p $release/$arch/sources
        mv output/$arch/*.src.rpm $dest/$arch/sources/
        createrepo_c $dest/$arch/sources/
    done

    rm -f $NVR_FILE
fi

