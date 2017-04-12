#!/usr/bin/bash

function usage ()
{
    echo "USAGE:"
    echo "recreate_srpm.sh ARCH SRPM"
}

TARGET_ARCH=$1
if [ x$TARGET_ARCH = "x" ]; then
    echo "Missing arch"
    usage
    exit 1
fi

SRPM=`realpath $2`
if [ $? -ne 0 ]; then
    echo "Missing SRPM"
    usage
    exit 2
fi

echo "Recreating $SRPM for $TARGET_ARCH"

mkdir -p $TARGET_ARCH

SRPM_DIR=`pwd`/$TARGET_ARCH
WORKING_DIR=`mktemp -d`

pushd $WORKING_DIR

rpm2cpio $SRPM | cpio --extract -d
rpmbuild -bs --build-in-place --target=$TARGET_ARCH \
         --define "_sourcedir $WORKING_DIR" \
         --define "_srcrpmdir $SRPM_DIR" *.spec
popd

rm -Rf $WORKING_DIR
