#!/usr/bin/bash

mock -r ./fedora-26-multiarch.cfg init
mock -r ./fedora-26-multiarch.cfg --chroot "mkdir -p /opt/srpm/output"
mock -r ./fedora-26-multiarch.cfg --copyin ./recreate_srpm.sh /opt/srpm/recreate_srpm.sh

mkdir -p output
mock -r ./fedora-26-multiarch.cfg --cwd=/opt/srpm/output --chroot /opt/srpm/recreate_srpm.sh $1
mock -r ./fedora-26-multiarch.cfg --copyout /opt/srpm/output ./output
