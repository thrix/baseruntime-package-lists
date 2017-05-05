#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Cwd 'getcwd';
use Cwd 'abs_path';
use File::Basename;

# pkgname => { build => build, ref => ref, arches => [arches] }
my %pkgs;
# runtime and buildroot package lists
my (@runtime, @buildroot);

my $fh;

sub HELP_MESSAGE {
    print "Usage: mkmmd.pl path [local_base_runtime_module_repo]\n";
    exit;
}

sub getbuild {
    return $_[0] =~ s/^\d+:(.+)\.[^.]+$/$1/r;
}

sub getname {
    return $_[0] =~ s/^(.+)-[^-]+-[^-]+$/$1/r;
}

my $path = shift @ARGV or HELP_MESSAGE;
my $brt_repo;
$brt_repo = shift @ARGV;

my $cwd = getcwd;
my $script_path = abs_path(dirname(__FILE__));

chdir $path;
for my $arch (glob("*")) {
    next unless -d $arch;
    my $list = "${arch}/selfhosting-source-packages-full.txt";
    next unless -f $list;
    open $fh, '<', $list;
    while (<$fh>) {
        chomp;
        my $build = getbuild $_;
        my $name = getname $build;
        $pkgs{$name} = { build => $build, ref => 'master', arches => [] }
            unless exists $pkgs{$name};
        push @{ $pkgs{$name}->{arches} }, $arch;
    }
    close $fh;
    $list = "${arch}/runtime-source-packages-short.txt";
    open $fh, '<', $list;
    while (<$fh>) {
        chomp;
        # we prune duplicates later
        push @runtime, $_;
    }
    close $fh;
}

{
    my %runtime;
    for (@runtime) {
        $runtime{$_} = 1;
    }
    @runtime = sort keys %runtime;
    @buildroot = grep { ! exists $runtime{$_} } sort keys %pkgs;
}

my $params = join(' ', map { $pkgs{$_}->{build} } sort keys %pkgs);
my $out = `python ${script_path}/get_package_hashes.py ${params}`;
while ($out =~ m/([^\/]+?):([a-f0-9]{40})/g) {
    $pkgs{$1}->{ref} = $2;
}

my $runtimetmpl = <<"EOF";
document: modulemd
version: 1
data:
    summary: The base application runtime and hardware abstraction layer
    description: >
        A project closely linked to the Modularity Initiative, Base Runtime
        is about defining the common shared package and feature set of the
        operating system, providing both the hardware enablement layer and
        the minimal application runtime environment other modules can build
        upon.
    license:
        module: [ MIT ]
    dependencies:
        buildrequires:
            bootstrap: master
    references:
        community: https://fedoraproject.org/wiki/BaseRuntime
        documentation: https://github.com/fedora-modularity/base-runtime
        tracker: https://github.com/fedora-modularity/base-runtime/issues
    profiles:
        baseimage:
            rpms:
                - bash
                - coreutils-single
                - filesystem
                - glibc-minimal-langpack
                - libcrypt
                - microdnf
                - rpm
                - shadow-utils
                - util-linux
        buildroot:
            rpms:
                - bash
                - bzip2
                - coreutils
                - cpio
                - diffutils
                - fedora-modular-release
                - findutils
                - gawk
                - gcc
                - gcc-c++
                - grep
                - gzip
                - info
                - make
                - patch
                - redhat-rpm-config
                - rpm-build
                - sed
                - shadow-utils
                - tar
                - unzip
                - util-linux
                - which
                - xz
        srpm-buildroot:
            rpms:
                - bash
                - fedora-modular-release
                - fedpkg-minimal
                - gnupg2
                - redhat-rpm-config
                - rpm-build
                - shadow-utils
    api:
        rpms: [
            ]
    filter:
        rpms: [
            ]
    components:
        rpms:
__COMPONENTS__
EOF
my $buildroottmpl = <<"EOF";
document: modulemd
version: 1
data:
    summary: Bootstrap the Modularity infrastructure
    description: >
        The purpose of this module is to provide a boostrapping mechanism
        for new distributions or architectures as well as the entire build
        environment for the Base Runtime module.
    license:
        module: [ MIT ]
    dependencies:
        buildrequires:
            bootstrap: master
    references:
        community: https://fedoraproject.org/wiki/BaseRuntime
        documentation: https://github.com/fedora-modularity/base-runtime
        tracker: https://github.com/fedora-modularity/base-runtime/issues
    profiles:
        buildroot:
            rpms:
                - bash
                - bzip2
                - coreutils
                - cpio
                - diffutils
                - fedora-release
                - findutils
                - gawk
                - gcc
                - gcc-c++
                - grep
                - gzip
                - info
                - make
                - patch
                - redhat-rpm-config
                - rpm-build
                - sed
                - shadow-utils
                - tar
                - unzip
                - util-linux
                - which
                - xz
        srpm-buildroot:
            rpms:
                - bash
                - fedora-release
                - fedpkg-minimal
                - gnupg2
                - redhat-rpm-config
                - rpm-build
                - shadow-utils
    components:
        rpms:
__COMPONENTS__
        modules:
            base-runtime:
                rationale: Bootstrapping requires Base Runtime.
                ref: master
__REPOSITORY__
EOF
my $componenttmpl = <<"EOF";
            # __BUILD__
            __NAME__:
                rationale: Autogenerated by Base Runtime tools.
                ref: __REF__
EOF
# let's populate the templates
my $components = '';
for my $pkg (@runtime) {
    my $tmpl = $componenttmpl;
    my ($build, $name, $ref) = ($pkgs{$pkg}->{build}, $pkg, $pkgs{$pkg}->{ref});
    $tmpl =~ s/__BUILD__/$build/;
    $tmpl =~ s/__NAME__/$name/;
    $tmpl =~ s/__REF__/$ref/;
    chomp $tmpl;
    $components .= "${tmpl}\n";
}
chomp $components;
$runtimetmpl =~ s/__COMPONENTS__/$components/;
$components = '';
for my $pkg (@buildroot) {
    my $tmpl = $componenttmpl;
    my ($build, $name, $ref) = ($pkgs{$pkg}->{build}, $pkg, $pkgs{$pkg}->{ref});
    $tmpl =~ s/__BUILD__/$build/;
    $tmpl =~ s/__NAME__/$name/;
    $tmpl =~ s/__REF__/$ref/;
    chomp $tmpl;
    $components .= "${tmpl}\n";
}
chomp $components;
$buildroottmpl =~ s/__COMPONENTS__/$components/;
if ($brt_repo) {
    $buildroottmpl =~ s#__REPOSITORY__#                repository: file://$brt_repo#;
} else {
    $buildroottmpl =~ s/__REPOSITORY__//
}
# dump it to disk
chdir $cwd;
open $fh, '>', './base-runtime.yaml';
print { $fh } $runtimetmpl;
close $fh;
open $fh, '>', './bootstrap.yaml';
print { $fh } $buildroottmpl;
close $fh;
