# Generating Base Runtime Lists

The depchase python module is an interface to the DNF API to perform
complicated lookups on package dependencies.

## Setup
This tool requires the following pre-requisites:
* python3-dnf >= 2.0 (See below)
* python3-click
* depchase (See below)

### Installing DNF 2.x on Fedora 24 and 25
```
$ dnf copr enable rpmsoftwaremanagement/dnf-nightly
$ dnf update python3-dnf
```

### Installing depchase

```
$ git clone https://github.com/sgallagher/depchase.git
$ cd depchase
$ python3 setup.py install --user
```
This will install the `depchase` command as `~/.local/bin/depchase`

You may wish to add this to your default PATH variable in `~/.bashrc` by doing:
```
$ echo "export PATH=$PATH:$HOME/.local/bin" >> ~/.bashrc
```
## Preparing the override repositories

These instructions require that you be a member of the `modularity-wg` group in
the Fedora Account System and that your SSH keys are properly set up for use
with Fedora infrastructure. See https://admin.fedoraproject.org/accounts for
full details.

### Syncing the existing repositories
You can pull down the existing repositories by chdir into the `repo/`
subdirectory and running `./rsync-pull.sh [<release>]` where `release` is either
 a final Fedora release number (such as `25`) or a pre-release in the format of
`test/26_Alpha`. If unspecified, the release will be kept in sync with whichever
 is the latest branched milestone as best as possible.

### Pushing to the override repositories

Copy any binary (or noarch) RPMs for inclusion into `repo/<release>/<arch>/os`.
For source RPMs, copy them to the `repo/<release>/<arch>/sources` path. Then
chdir into `repo/` and run `./rsync-push.sh [<release>]`. This will
automatically update the repo metadata and rsync the contents to the
fedorapeople repository.

There is a helper utility in the root of the git repository called `dl_pkgs.sh`.
This utility must be called with one argument: a path to a file containing one
package NVR or Koji build-id per line. If it is an NVR, the package must be an
official build in Koji. For a build-id, a scratch-build may work (but is
untested).

## Dealing with SRPMs with arch-specific BuildRequires
Some packages have differing BuildRequires depending on which platform is being
built. In these cases, in order to have the list generation find the right
values, we need to pull down those SRPMs and regenerate them for every
architecture that we process.

There is a helper utility in the root of the git repository called
`mock_wrapper.sh` which takes a single argument: a list of NVRs of official Koji
builds that should be regenerated. It will construct a mock buildroot with
limited packages (to reduce the risk that the output could be different
depending on the packages available in the host system), check out each of the
requested SRPM packages and regenerate them on each architecture. It will then
drop them into a directory `./output` (clobbering any existing content!) relative
to the working directory that was executed.

Once that content is present, you can run `./populate_srpm_repo.sh [<release>]`
from the root of the git repository, which will move all of the `./output`
contents into the `repo/` hierarchy, after which you can follow the "Pushing to
the override repositories" instructions above.

## How to run:
Ensure that the contents of `toplevel-binary-packages.txt` and `hints.txt` in
each of the `data/$OS/$VERSION[_$MILESTONE]/$ARCH` directories is correct.

`toplevel-binary-packages.txt` contains the set of packages that the base
runtime must contain in order to provide the requisite APIs.

`hints.txt` is a manually-curated set of packages that is used to resolve
ambiguities in dependencies. For example, the `glibc` package
`Requires: glibc-langpack` and many packages may `Provides: glibc-langpack`, so
we include `glibc-minimal-langpack` in the hints.txt to resolve this decision.


Then call generatelists.py with the following arguments:

```
Usage: generatelists.py [OPTIONS]

Options:
  --os TEXT          What OS to process?
  --version INTEGER  What OS version to process?
  --milestone TEXT   If processing a prerelease, which one?
  --help             Show this message and exit.
```

For example:
```
./generatelists.py --version 26 --milestone Alpha
```

