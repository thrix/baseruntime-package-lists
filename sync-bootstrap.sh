#!/bin/sh
rm -fv /tmp/bootstrap*

cat data/Fedora/devel/bootstrap/*/selfhosting-source-packages-full.txt \
    | sed -e 's/-[0-9][0-9]*:/-/' \
    | sed -e 's/\.src$//' \
    | sort -u \
    > /tmp/bootstrap.unified
koji list-tagged --quiet module-bootstrap-rawhide \
    | sed -e 's/ .*$//' \
    | sort -u \
    > /tmp/bootstrap.tagged

tag=$(comm -1 -3 /tmp/bootstrap.tagged /tmp/bootstrap.unified)
untag=$(comm -2 -3 /tmp/bootstrap.tagged /tmp/bootstrap.unified | grep -v '^Fedora')

if [ "x${tag}" = "x" -a "x${untag}" = "x" ]; then
    echo "The tag is up to date.  Nothing to do."
    exit
fi

echo "Packages to be tagged"
echo "---------------------"
echo $tag
echo
echo "Packaged to be untagged"
echo "-----------------------"
echo $untag
echo
echo -n "Proceeding with with the sync in "
for n in $(seq 5 -1 1); do
    echo -n "${n}... "
    sleep 1
done
echo
if [ "x${tag}" != "x" ]; then
    for pkg in $tag; do
        echo -n "Tagging ${pkg}... "
        koji tag-build module-bootstrap-rawhide --nowait $pkg
    done
fi
if [ "x${untag}" != "x" ]; then
    for pkg in $untag; do
        echo "Untagging ${pkg}..."
        koji untag-build module-bootstrap-rawhide $pkg
    done
fi
