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
In order for this tool to be able to take further updates into account, they
must be loaded into a public repository under
https://fedorapeople.org/groups/modularity/repos/fedora/gencore-override/
in the format
`https://fedorapeople.org/groups/modularity/repos/fedora/gencore-override/$VERSION/$ARCH`,
where `$VERSION` is either the numeric value of the final release or else
`test/$VERSION_$MILESTONE`, such as `test/26_Alpha`.

A tool to help manage this will be forthcoming in this repository.

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

