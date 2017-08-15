#!/bin/sh
self=$(basename "$0")
status=0
files=$(find data/Fedora \
    -type f \
    -name '*-packages-*.txt' \
    -not -path '*26*' \
    | sort)
for f in $files; do
    lines=$(wc -l $f | sed 's/ .*$//')
    if [ $lines -eq 0 ]; then
        echo "Empty file list found: $f"
        status=1
    fi
done
[ $status -eq 0 ] && echo "${self} test OK!" || echo "${self} test FAILED!"
exit $status
