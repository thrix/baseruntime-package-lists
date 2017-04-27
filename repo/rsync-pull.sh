#!/usr/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROCESSORS=$(/usr/bin/getconf _NPROCESSORS_ONLN)

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

    # Get the correct koji tag
    # This has to be fN-build because otherwise it won't find glibc32
    KOJI_TAG=$(koji list-targets |grep "^rawhide\s"|awk '{print $2}')

    cat $SCRIPT_DIR/../archful-srpms.txt \
    | xargs koji latest-build $KOJI_TAG  --quiet \
    | cut -f 1 -d " " \
    > $NVR_FILE

    # Generate the archful SRPMs
    $SCRIPT_DIR/../mock_wrapper.sh rawhide $NVR_FILE

    # Put the resulting SRPMs into place
    # As well as the RPMS from Koji
    for arch in "x86_64" "i686" "armv7hl" "aarch64" "ppc64" "ppc64le"; do
        # Copy the generated SRPMs
        mkdir -p $release/$arch/sources
        mv output/$arch/*.src.rpm $dest/$arch/sources/

        # Pull down the previously-built RPMs from Koji
        # This will avoid issues where a koji build is newer than
        # what's available in the repo as well as ensuring that
        # special packages like glibc32 are in place.
        mkdir -p $release/$arch/os
        pushd $release/$arch/os
            set +e
            cat $NVR_FILE \
            | xargs --max-procs=$PROCESSORS -I NVR \
              koji download-build --arch=noarch --arch=$arch NVR
            set -e
        popd

        createrepo_c $dest/$arch/sources/
        createrepo_c $dest/$arch/os/
    done

    rm -f $NVR_FILE
fi

