#!/usr/bin/bash

function usage ()
{
    echo "USAGE:"
    echo "recreate_srpm.sh <ARCH> <NVR>"
}

TARGET_ARCH=$1
if [ x$TARGET_ARCH = "x" ]; then
    echo "Missing arch"
    usage
    exit 1
fi

NVR=$2
if [ "x$NVR" = "x" ]; then
    echo "Missing NVR"
    usage
    exit 2
fi

PKG_AND_GIT=($(koji buildinfo $NVR | \
             awk '{ match($0, /\/(^:+):([a-f0-9]+)\)/, arr); \
                  if(arr[1] != "") print arr[1]; \
                  if(arr[2] != "") print arr[2] }'))

DIST_GIT_REPO=${PKG_AND_GIT[0]}
PKG=`basename $DIST_GIT_REPO`
GIT_COMMIT=${PKG_AND_GIT[1]}

echo "Generating $PKG SRPM for $TARGET_ARCH from commit $GIT_COMMIT"

mkdir -p $TARGET_ARCH

SRPM_DIR=`pwd`/$TARGET_ARCH
WORKING_DIR=`mktemp -d`

pushd $WORKING_DIR

fedpkg clone -a $DIST_GIT_REPO
pushd $PKG
git reset --hard $GIT_COMMIT
fedpkg sources

rpmbuild -bs --build-in-place --target=$TARGET_ARCH \
         --define "_sourcedir $WORKING_DIR/$PKG" \
         --define "_srcrpmdir $SRPM_DIR" *.spec
popd
popd

rm -Rf $WORKING_DIR
