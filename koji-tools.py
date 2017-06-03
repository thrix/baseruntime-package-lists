#!/usr/bin/env python

import os
import click
import koji
from six.moves.urllib_parse import urljoin

KOJIPKGS = "https://kojipkgs.fedoraproject.org/"
KOJIHUB = "https://koji.fedoraproject.org/kojihub"

@click.group()
def kojicli():
    pass

@kojicli.command("get-latest-repo")
@click.argument("tag")
def get_latest_repo(tag):
    """Find latest repo ID and its URL for tag name.

    \b
    Example of output:
    756330 https://kojipkgs.fedoraproject.org/repos/f27-build/756330
    """
    ks = koji.ClientSession(KOJIHUB)
    pathinfo = koji.PathInfo(topdir="")

    repo = ks.getRepo(tag, state=koji.REPO_READY)
    repo_id = repo["id"]
    path = pathinfo.repo(repo_id, tag)
    click.echo("{} {}".format(repo_id, urljoin(KOJIPKGS, path)))

@kojicli.command("get-source-packages")
@click.argument("tag")
@click.argument("repo_id", type=int)
def get_source_packages(tag, repo_id):
    """Find URLs to SRPMs used in repo ID for tag name."""
    ks = koji.ClientSession(KOJIHUB)
    pathinfo = koji.PathInfo(topdir="")

    tinfo = ks.getTag(tag, strict=True)
    tag_id = tinfo["id"]
    repos = ks.getActiveRepos()
    # let's filter all active repos by tag
    repos = (repo for repo in repos if repo["tag_id"] == tag_id)
    try:
        repo = next(repo for repo in repos if repo["id"] == repo_id)
    except StopIteration:
        raise koji.GenericError("No active repo for specified tag and id: {!r}, {!r}".format(tag, repo_id))
    event_id = repo["create_event"]

    rpms, builds = ks.listTaggedRPMS(tag_id, event=event_id, inherit=True, latest=True, arch="src")
    build_idx = {b["id"]: b for b in builds}
    for rpm in rpms:
        build = build_idx[rpm["build_id"]]
        builddir = pathinfo.build(build)
        path = os.path.join(pathinfo.build(build), pathinfo.rpm(rpm))
        click.echo(urljoin(KOJIPKGS, path))

if __name__ == "__main__":
    kojicli()
