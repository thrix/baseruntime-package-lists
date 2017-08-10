#!/usr/bin/perl
# ABSTRACT: Generate modulemd files for the Host & Platform
use 5.014;
use strict;
use warnings;
use autodie;
use Getopt::Std;
use IPC::Open3;
use List::Util 1.33 qw/any/;
use Template;
use Text::CSV_XS qw/csv/;
use Text::Wrap;

$Text::Wrap::columns = 80;
$Text::Wrap::unexpand = 0;

# This script generates all the base modulemd files implementing
# the Host & Platform concept.  This includes the following:
#
#   * bootstrap
#   * platform
#   * host
#   * shim
#   * atomic
#
# Unlike with Base Runtime, the Bootstrap module doesn't include
# any other directly.  This is to allow greater flexibility for
# development of multiple different Platforms using the same
# Bootstrap module.
#
# The policy for package placement is currently hardcoded but
# might be moved into external files in the future.  Right now
# the implementation strives to do the following:
#
#   * The Bootstrap module includes all the self-hosting
#     components for all of the supported architectures with
#     the exception of shim*.
#     The module requires itself as a build dependency and
#     has no runtime dependencies whatsoever.
#   * The Shim module only includes packages explicitly listed
#     in it.  It requires the Bootstrap module at build time
#     and for practical purposes has no runtime dependencies.
#   * The Host module includes only packages explicitly listed
#     in it.  The module depends on the Bootstrap and Shim
#     modules at build and on the Platform module at runtime.
#   * The Platform module includes the remainder of the non-Atomic
#     runtime components, satisfying runtime dependencies of the
#     Host.  It depends on the Bootstrap module at build time and
#     has no runtime dependencies.
#   * The Atomic module includes components needed to boot an
#     Atomic-based faster moving host.  This module is almost
#     entirely independent, only sharing the build environment
#     with the Host & Platform module set.

sub HELP_MESSAGE {
    print <<"    EOF";
Usage: make_modulemd.pl [-b] [-v] <path to package lists>

Generate the Atomic Host module:
  ./make_modulemd.pl ./data/Fedora/devel/atomic
Generate the complete Host & Platform set:
  ./make_modulemd.pl ./data/Fedora/devel/hp
Generate the extended Bootstrap module only:
  ./make_modulemd.pl ./data/Fedora/devel/bootstrap

Options:
  -v  Verbose.  Prints more information to stderr.
    EOF
    exit 1;
}

my %opts;
getopts('v', \%opts);

my $base = shift @ARGV or HELP_MESSAGE;
-d $base or HELP_MESSAGE;
my ($mode) = $base =~ /\/([^\/]+)$/;

# Get a simple NVR from a NEVRA SRPM name.
sub getnvr {
    $_[0] =~ s/^(.+?)-(?:\d+:)?([^-]+-[^-]+)(?:\.[^.]+)$/$1-$2/r;
}

# Get a package name from NVR
sub getn {
    $_[0] =~ s/^(.+)-[^-]+-[^-]+$/$1/r;
}

# Get dist-git refs for NVRs
sub getrefs {
    print { *stderr } "Getting ${mode} component dist-git refs...\n"
        if $opts{v};
    my %refs = map {
        # XXX: Special hacks for shim.  This needs to be updated
        #      in the rare case of a shim rebase, although we should
        #      probably handle this with arbitrary branching; make
        #      sure the branched content works together and referce
        #      that rather than specific commits.
        my $ref = undef;
        if (getn($_) eq 'shim-signed') {
            # Bundles binaries from the unsigned packages.
            $ref = 'private-psabata-base-runtime-f26';
        } elsif (getn($_) eq 'shim') {
            $ref = '72c0daf8e4db63bd5b8125167e23164e515198c4';
        } elsif (getn($_) eq 'shim-unsigned-aarch64') {
            $ref = 'ae09b5fe2bac419ce2b49bded0487d133bd53919';
        }
        $_ => $ref;
    } @_;
    # XXX: koji python multicall API is much faster than CLI, so...
    my ($pyin, $pyout, $pyerr);
    my $pid = open3($pyin, $pyout, $pyerr,
        '/usr/bin/python2 - '.join(' ', @_));
    print { $pyin } <<"    EOF";
import sys
import koji

args = sys.argv[1:]
nvrs = []
ks = koji.ClientSession('https://koji.fedoraproject.org/kojihub')
ks.multicall = True
for build in args:
    ks.getBuild(build)
ret = ks.multiCall(strict=True)
ks.multicall = True
for i in range(len(args)):
    if ret[i][0] is not None:
        if ret[i][0]['task_id'] is not None:
            ks.getTaskInfo(ret[i][0]['task_id'], request=True)
            nvrs.append(args[i])
ret = ks.multiCall(strict=True)
for i in range(len(nvrs)):
    print nvrs[i], koji.taskLabel(ret[i][0])
    EOF
    close $pyin;
    while (<$pyout>) {
        chomp;
        /^(?<nvr>[^ ]+)\sbuild\s
         \([^,]+,\s(?:\/rpms)?\/(?:[^:]+):(?<ref>[^)]+)\)$/x;
        $refs{$+{nvr}} //= $+{ref};
    }
    waitpid($pid, 0);
    { %refs };
}

my @arches = qw/aarch64 armv7hl i686 ppc64 ppc64le s390x x86_64/;
# XXX: Make sure platform is the last one so that we can reuse data from the
#      host and shim data files.  This should be done in a better way but meh.
my @modules = qw/bootstrap atomic host shim platform/;
# Map of components and their hashes
my %components;
# And just the runtime set
my %runtime;

for my $arch (@arches) {
    print { *stderr } "Reading ${mode} / ${arch} package lists...\n"
        if $opts{v};
    open my $fh, '<', "${base}/${arch}/selfhosting-source-packages-full.txt";
    while (<$fh>) {
        chomp;
        # Just make sure it's defined
        $components{getnvr($_)} = undef;
    }
    close $fh;
    open $fh, '<', "${base}/${arch}/runtime-source-packages-full.txt";
    while (<$fh>) {
        chomp;
        $runtime{getnvr($_)} = undef;
    }
    close $fh;
}
%components = getrefs(keys %components);

my $default_rationale = 'Autogenerated by Host & Platform tooling.';
my $default_ref = 'master';

# Populate with non-platform packages.  Make sure they're processed first.
my %nonplatform;

for my $module (@modules) {
    next if $mode eq 'bootstrap' && $module ne 'bootstrap';
    next if $mode eq 'atomic' && $module ne 'atomic';
    next if $mode eq 'hp' && $module !~ /^(?:platform|host|shim)$/;
    print { *stderr } "Generating ${mode} / ${module}...\n"
        if $opts{v};
    my $tt = Template->new( {
            INCLUDE_PATH => ${base},
            ABSOLUTE => 1,
            RELATIVE => 1 }
    );
    my %data;
    my %rationales = map {
            $_->[0] => $_->[1]
                ? wrap('', ' 'x20, ucfirst($_->[1]) . '.')
                : undef;
        } @{ csv(in => "${base}/${module}.csv") };
    if ($module eq 'bootstrap') {
        $data{components} = { map {
            getn($_) => {
                nvr => $_,
                ref => $components{$_} // $default_ref,
                rationale => $rationales{getn($_)} // $default_rationale,
            }
        } grep {
            # Let's not bother with shim in Bootstrap.  It wouldn't build.
            ! /^shim-/;
        } keys %components };
    } elsif ($module =~ /^(?:host|shim)$/) {
        $data{components} = { map {
            getn($_) => {
                nvr => $_,
                ref => $components{$_} // $default_ref,
                rationale => $rationales{getn($_)} // $default_rationale,
            }
        } grep {
            my $tmp = $_; any { $_ eq getn($tmp) } keys %rationales;
        } keys %components };
        map { $nonplatform{$_} = undef } keys %rationales;
    } elsif ($module =~ /^(?:atomic|platform)$/) {
        $data{components} = { map {
            getn($_) => {
                nvr => $_,
                ref => $components{$_} // $default_ref,
                rationale => $rationales{getn($_)} // $default_rationale,
            }
        } map {
            # XXX: A special hack to translate the traditional
            # release and repos to the modular variants.  We need
            # fedora-release/repos for the depsolving to work
            # but we don't want it in the resulting module where
            # fedora-modular-release/repos implement their features.
            # We only do this for platform as bootstrap needs the original
            # at the moment.
            # We need the hardcoded versions so that getn() doesn't mangle
            # the names to simple "fedora" later on.  It doesn't matter
            # they don't exist.  We manage that content in Rawhide anyway.
            if (/^fedora-release-.+$/) {
                'fedora-modular-release-27-1';
            } elsif (/^fedora-repos-.+$/) {
                'fedora-modular-repos-27-1';
            } else {
                $_;
            }
        } grep {
            $module eq 'atomic'
            ? 1
            : ! exists $nonplatform{getn($_)};
        } keys %runtime };
    } else {
        die "Unhandled module: ${module}\n";
    }
    $tt->process("${base}/${module}.tmpl", \%data, "${base}/${module}.yaml")
        or die "Error while processing templates: " . $tt->error() . "\n";
}

print "Done with ${mode}.\n"
    if $opts{v};
