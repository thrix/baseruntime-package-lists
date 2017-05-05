#!/usr/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -e

# Email should go to the addresses specified on the command line
# or else default to sgallagh@redhat.com
MAIL_RECIPIENTS=${@:-"sgallagh@redhat.com"}

CHECKOUT_PATH=$(mktemp -d)
attachment_dir=$(mktemp -d)

# Make sure we have the latest copy of depchase
pushd $CHECKOUT_PATH
git clone https://github.com/fedora-modularity/depchase.git
pushd depchase

python3 setup.py install --user
export PATH=$PATH:$HOME/.local/bin
popd # depchase
popd # CHECKOUT_PATH
rm -Rf $CHECKOUT_PATH


pushd $SCRIPT_DIR

COMMIT_DATE=$(git log -1 --pretty="%cr (%cd)")

# Pull down the current override repository from fedorapeople
# We will put this in a permanent location (not purged at the end of the run)
# to save time on future runs of the script
$SCRIPT_DIR/repo/rsync-pull.sh rawhide $HOME/override_repo/

STDERR_FILE=$(mktemp)
$SCRIPT_DIR/generatelists.py --os Rawhide --local-override \
                             $HOME/override_repo \
                             2> $STDERR_FILE
errs=$(cat $STDERR_FILE)
rm -f $STDERR_FILE




# Create a temporary git repository for the metadata
brt_tmp_dir=$(mktemp -d)
brt_dir=$brt_tmp_dir/base-runtime
bootstrap_dir=$brt_tmp_dir/bootstrap
mkdir -p $brt_dir $bootstrap_dir

# Generate module metadata for the base runtime and bootstrap
$SCRIPT_DIR/make_modulemd.pl $SCRIPT_DIR/data/Rawhide $brt_dir

cp base-runtime.yaml $brt_dir/
cp boostrap.yaml $bootstrap_dir/
pushd $brt_dir

git init
git add base-runtime.yaml
git commit -m "Committing base-runtime.yaml"

popd # $brt_dir

pushd $bootstrap_dir

git init
git add bootstrap.yaml
git commit -m "Committing bootstrap.yaml"

mbs-build local

gzip module_build_service.log
cp module_build_service.log.gz $attachment_dir


popd # $bootstrap_dir

rm -Rf $brt_tmp_dir

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

# Always carry the complete diff as an attachment
# this will include all of the relevant NVRs
git diff data/Rawhide > $attachment_dir/package_changes.diff

# Check whether our
if [ $modified -gt 0 ]; then
    filediff=$(git diff --no-color *short.txt)
    body="$body
The following changes were detected since $COMMIT_DATE:

$filediff
"
fi

echo "$body" | \
mail -s "[Base Runtime] Nightly Rawhide Depchase" \
     -S "from=The Base Runtime Team <rhel-next@redhat.com>" \
     -a $attachment_dir/package_changes.diff \
     -a $attachment_dir/module_build_service.log.gz \
     $MAIL_RECIPIENTS

rm -Rf $complete_diff_dir

# Reset the git commit for future runs

popd # SCRIPT_DIR

