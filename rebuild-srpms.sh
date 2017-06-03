#!/bin/sh -eu

TMPDIR=$(mktemp -d --suffix "-rebuild-srpms")
trap 'rm -rf "$TMPDIR"' EXIT

rebuild_srpm() {
  local tmpdir="$1" srpm="$2" arch="$3"
  local topdir_tmp="$tmpdir/$srpm.$arch"
  mkdir $topdir_tmp

  echo "Rebuilding $srpm for $arch"

  dist=$(rpm -qp --qf "%{release}\n" "$srpm" | grep -Po "\.fc\d+")
  echo "%dist is set to: $dist"

  rpmbuild -rs --nodeps --target "$arch" "$srpm" \
    -D "dist $dist" \
    -D "_topdir $topdir_tmp" \
    -D "_srcrpmdir $arch/sources" 

  rm -rf $topdir_tmp
}
export -f rebuild_srpm

parallel -j 100% rebuild_srpm "$TMPDIR" ::: *.src.rpm ::: aarch64 armv7hl i686 ppc64 ppc64le s390x x86_64
