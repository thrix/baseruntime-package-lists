#!/usr/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -e

# Email should go to the addresses specified on the command line
# or else default to sgallagh@redhat.com
MAIL_RECIPIENTS=${@:-"sgallagh@redhat.com"}

CHECKOUT_PATH=$(mktemp -d)

# Make sure we have the latest copy of depchase
pushd $CHECKOUT_PATH
git clone https://github.com/fedora-modularity/depchase.git
pushd depchase

python3 setup.py install --user
export PATH=$PATH:$HOME/.local/bin
popd # depchase

git clone https://github.com/fedora-modularity/baseruntime-package-lists.git
pushd baseruntime-package-lists

COMMIT_DATE=$(git log -1 --pretty="%cr (%cd)")

# Pull down the current override repository from fedorapeople
# We will put this in a permanent location (not purged at the end of the run)
# to save time on future runs of the script
$SCRIPT_DIR/repo/rsync-pull.sh rawhide $HOME/override_repo/

./generatelists.py --os Rawhide --local-override $HOME/override_repo/rawhide 2> ./stderr.txt
errs=$(cat stderr.txt)

# This script doesn't run any git commands, so we know that we can only
# end up with modified files.
# Let's get the list of short RPMs here so we can see if the list has
# grown or shrunk since the last saved run.
modified=$(git status --porcelain=v1  *short.txt |cut -f 3 -d " "|wc -l)

body="Heyhowareya!

This is your automated Base Runtime Rawhide depchase report!
The output from the latest update run can be found below.

First: here's the list of errors that depchase encountered during processing:

$errs

"

if [ $modified -gt 0 ]; then
    filediff=$(git diff --no-color *short.txt)
    body="$body
The following changes were detected since $COMMIT_DATE:

$filediff
"

echo "$body" | \
mail -s "[Base Runtime] Nightly Rawhide Depchase" \
     -S "from=The Base Runtime Team <rhel-next@redhat.com>" \
     $MAIL_RECIPIENTS

popd # baseruntime-package-lists
popd # CHECKOUT_PATH
fi

rm -Rf $CHECKOUT_PATH
