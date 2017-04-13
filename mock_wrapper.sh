#!/usr/bin/bash
# Usage: ./mock_wrapper.sh <NVR file>

set -e
PROCESSORS=$(/usr/bin/getconf _NPROCESSORS_ONLN)

mock -r ./fedora-26-multiarch.cfg init
mock -r ./fedora-26-multiarch.cfg --chroot "mkdir -p /opt/srpm/output"
mock -r ./fedora-26-multiarch.cfg --copyin ./recreate_srpm.sh \
                                           /opt/srpm/recreate_srpm.sh
mock -r ./fedora-26-multiarch.cfg --copyin $1 \
                                           /opt/srpm/srpms.txt
mock -r ./fedora-26-multiarch.cfg --cwd=/opt/srpm/output --chroot \
    "cat /opt/srpm/srpms.txt | xargs --max-procs=$PROCESSORS -I NVR \
    /opt/srpm/recreate_srpm.sh NVR"
rm -Rf ./output
mock -r ./fedora-26-multiarch.cfg --copyout /opt/srpm/output ./output
