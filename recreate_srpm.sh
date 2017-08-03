#!/usr/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function usage ()
{
    echo "USAGE:"
    echo "recreate_srpm.sh <NVR> [--bumpspec]"
}

NVR=$1
if [ "x$NVR" = "x" ]; then
    echo "Missing NVR"
    usage
    exit 1
fi

PKG_AND_GIT=($($SCRIPT_DIR/get_package_hashes.py $NVR | \
             awk '{ match($0, /\/([^:]+):([a-f0-9]+)\)/, arr); \
                  if(arr[1] != "") print arr[1]; \
                  if(arr[2] != "") print arr[2] }'))
if [ $? -ne 0 ]; then
    echo "Error getting buildinfo"
    exit 1
fi

DIST_GIT_REPO=${PKG_AND_GIT[0]}
if [ "x$DIST_GIT_REPO" = "x" ]; then
    echo "Invalid NVR"
    exit 1
fi

PKG=`basename $DIST_GIT_REPO`
GIT_COMMIT=${PKG_AND_GIT[1]}
if [ "x$GIT_COMMIT" = "x" ]; then
    echo "Git commit not found"
    exit 1
fi


echo "Generating $PKG SRPMs from commit $GIT_COMMIT"

OUTPUT_DIR=`pwd`
WORKING_DIR=`mktemp -d`

pushd $WORKING_DIR

fedpkg clone -a $DIST_GIT_REPO
pushd $PKG
git reset --hard $GIT_COMMIT
fedpkg sources

if [ "x$2" = "x--bumpspec" ]; then
    # Bump the version so it's guaranteed to sort higher
    rpmdev-bumpspec -s 0.override. \
                    -c "Regenerating SRPM for each architecture." \
                    -u "Base Runtime Team <devel@lists.fedoraproject.org>" \
                    $PKG.spec
fi

for arch in "x86_64" "i686" "armv7hl" "aarch64" "ppc64" "ppc64le" "s390x"; do
    mkdir -p $OUTPUT_DIR/$arch
    rpmbuild -bs --build-in-place --target=$arch \
             --define "_sourcedir $WORKING_DIR/$PKG" \
             --define "_srcrpmdir $OUTPUT_DIR/$arch" $PKG.spec
done

popd
popd

rm -Rf $WORKING_DIR
