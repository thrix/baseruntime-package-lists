#!/bin/sh
self=$(basename "$0")
status=0
files=$(find data/Fedora -type f -name '*-full.txt' | sort)
for f in $files; do
    dups=$(sed -e 's/-[^-]*-[^-]*$//' $f | uniq -d)
    if [ -n "$dups" ]; then
        echo "Duplicate packages found in $f:"
        echo "$dups"
        status=1
    fi
done
[ $status -eq 0 ] && echo "${self} test OK!" || echo "${self} test FAILED!"
exit $status
