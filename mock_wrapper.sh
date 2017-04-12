#!/usr/bin/bash

set -e

mock -r ./fedora-26-multiarch.cfg init
mock -r ./fedora-26-multiarch.cfg --chroot "mkdir -p /opt/srpm/output"
mock -r ./fedora-26-multiarch.cfg --copyin ./recreate_srpm.sh /opt/srpm/recreate_srpm.sh

mock -r ./fedora-26-multiarch.cfg --cwd=/opt/srpm/output --chroot /opt/srpm/recreate_srpm.sh $1
rm -Rf ./output
mock -r ./fedora-26-multiarch.cfg --copyout /opt/srpm/output ./output
