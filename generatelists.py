#!/usr/bin/python3

import os
import sys
import pprint
import click

from collections import namedtuple
from multiprocessing import Process, JoinableQueue

from depchase.exceptions import NoSuchPackageException
from depchase.io import output_results
from depchase.process import recurse_package_deps
from depchase.process import recurse_self_host
from depchase.process import resolve_ambiguity
from depchase.queries import get_pkg_by_name
from depchase.queries import get_srpm_for_package_name
from depchase.repoconfig import prep_repositories
from depchase.util import split_pkgname

NUM_PROCS = os.sysconf("SC_NPROCESSORS_ONLN")

DepchaseContext = namedtuple("DepchaseContext",
                             [
                                 'arch',
                                 'os',
                                 'version',
                                 'milestone',
                                 'hints',
                                 'pkgfile',
                                 'hintfile',
                             ])

def process_dependencies(arch_queue):
    while True:
        depchase_ctx = arch_queue.get()
        if depchase_ctx is None:
            break

        print("Arch: %s" % (depchase_ctx.arch))

        if depchase_ctx.os == 'Rawhide':
            base_path = "./data/Rawhide/%s/" % depchase_ctx.arch

        elif depchase_ctx.milestone:
            base_path = "./data/%s/%d_%s/%s/" % (
                         depchase_ctx.os,
                         depchase_ctx.version,
                         depchase_ctx.milestone,
                         depchase_ctx.arch)
        else:
            base_path = "./data/%s/%d/%s/" % (
                         depchase_ctx.os,
                         depchase_ctx.version,
                         depchase_ctx.arch)

        # Load the repository for this search
        query = prep_repositories(depchase_ctx.os,
                                  depchase_ctx.version,
                                  depchase_ctx.milestone,
                                  depchase_ctx.arch)

        # Read in the package names
        with open(os.path.join(base_path, depchase_ctx.pkgfile)) as f:
            pkgnames = f.read().splitlines()

        # Read in the hints
        with open(os.path.join(base_path, depchase_ctx.hintfile)) as f:
            hints = f.read().splitlines()

        # Don't process whatreqs or filters
        filters = []
        whatreqs = []


        dependencies = {}
        ambiguities = []

        # First process the standard dependencies
        for fullpkgname in pkgnames:
            (pkgname, pkgarch) = split_pkgname(fullpkgname, depchase_ctx.arch)

            try:
                pkg = get_pkg_by_name(query, pkgname, pkgarch)
            except NoSuchPackageException:
                print("%s was not found on architecture %s" % (
                        pkgname, pkgarch),
                      file=sys.stderr)
                continue

            recurse_package_deps(pkg, depchase_ctx.arch, dependencies, ambiguities, query,
                                 hints, filters, whatreqs, False, False)

        # Check for unresolved deps in the list that are present in the
        # dependencies. This happens when one package has an ambiguous dep
        # but another package has an explicit dep on the same package.
        # This list comprehension just returns the set of dictionaries that
        # are not resolved by other entries
        ambiguities = [x for x in ambiguities
                       if not resolve_ambiguity(dependencies, x)]

        # Get the source packages for all the dependencies
        srpms = {}
        for key, pkg in dependencies.items():
            srpm_pkg = get_srpm_for_package_name(query, pkg.name,
                                                 depchase_ctx.arch)
            srpms[srpm_pkg.name] = srpm_pkg

        # Print the complete set of dependencies together
        output_results(dependencies, srpms, depchase_ctx.arch,
                       os.path.join(base_path, 'runtime-binary-packages-short.txt'),
                       os.path.join(base_path, 'runtime-binary-packages-full.txt'),
                       os.path.join(base_path, 'runtime-source-packages-short.txt'),
                       os.path.join(base_path, 'runtime-source-packages-full.txt'))

        if len(ambiguities) > 0:
            print("=== Unresolved Requirements ===",
                  file=sys.stderr)
            pp = pprint.PrettyPrinter(indent=4)
            pp.pprint(ambiguities)

        # Then do the self-hosted dependencies
        binary_pkgs = {}
        source_pkgs = {}
        ambiguities = []
        for fullpkgname in pkgnames:
            (pkgname, pkgarch) = split_pkgname(fullpkgname, depchase_ctx.arch)

            pkg = get_pkg_by_name(query, pkgname, pkgarch)

            recurse_self_host(pkg, depchase_ctx.arch,
                              binary_pkgs, source_pkgs,
                              ambiguities, query, hints, filters,
                              whatreqs, False, False)

        # Check for unresolved deps in the list that are present in the
        # dependencies. This happens when one package has an ambiguous dep but
        # another package has an explicit dep on the same package.
        # This list comprehension just returns the set of dictionaries that
        # are not resolved by other entries
        # We only search the binary packages here. This is a reduction; no
        # additional packages are discovered so we don't need to regenerate
        # the source RPM list.
        ambiguities = [x for x in ambiguities
                       if not resolve_ambiguity(binary_pkgs, x)]

        # Print the complete set of dependencies together
        output_results(binary_pkgs, source_pkgs, depchase_ctx.arch,
                       os.path.join(base_path, 'selfhosting-binary-packages-short.txt'),
                       os.path.join(base_path, 'selfhosting-binary-packages-full.txt'),
                       os.path.join(base_path, 'selfhosting-source-packages-short.txt'),
                       os.path.join(base_path, 'selfhosting-source-packages-full.txt'))

        if len(ambiguities) > 0:
            print("=== Unresolved Requirements ===", file=sys.stderr)
            pp = pprint.PrettyPrinter(indent=4, stream=sys.stderr)
            pp.pprint(ambiguities)


        arch_queue.task_done()

@click.command()
@click.option('--os', default='Fedora',
              help='What OS to process? ("Fedora", "Rawhide")')
@click.option('--version', default=25,
              help='What OS version to process?')
@click.option('--milestone', default=None,
              help='If processing a prerelease, which one?')
def main(os, version, milestone):
    arch_queue = JoinableQueue()

    arches = ('x86_64', 'aarch64', 'i686', 'armv7hl', 'ppc64', 'ppc64le')

    processes = []
    # Create parallel processes for each architecture,  up to the limit of
    # processors on the system.
    for i in range(min(NUM_PROCS, len(arches))):
            worker = Process(target=process_dependencies,
                             args=(arch_queue,))
            worker.daemon = True
            worker.start()
            processes.append(worker)

    # Enqueue all of the architectures
    for arch in arches:
        dc_ctx = DepchaseContext(arch=arch,
                                 os=os,
                                 version=version,
                                 milestone=milestone,
                                 hints=[],
                                 pkgfile='toplevel-binary-packages.txt',
                                 hintfile='hints.txt')
        arch_queue.put(dc_ctx)

    # Wait for all the magic to happen
    arch_queue.join();

    # Terminate worker processes
    for i in range(min(NUM_PROCS, len(arches))):
        arch_queue.put(None);
    for worker in processes:
        worker.join()

if __name__ == "__main__":
    main()
