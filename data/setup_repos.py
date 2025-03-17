#!/usr/bin/python3

# Copyright Red Hat
#
# This file is part of os-autoinst-distri-fedora.
#
# This file is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author: Adam Williamson <awilliam@redhat.com>

"""
Package download and repository setup script for openQA update tests.
This script uses asyncio to download the packages to be tested, and
any 'workaround' packages, concurrently, and create repositories and
repository configuration files for them. This is work that used to be
done in-line in the test scripts, but doing it that way is slow for
large multi-package updates.
"""

import argparse
import asyncio
import glob
import os
import pathlib
import shutil
import subprocess
import sys

# these are variables to make testing this script easier...change them
# to /tmp for testing
WORKAROUNDS_DIR = "/mnt/workarounds_repo"
UPDATES_DIR = "/mnt/update_repo"
UPDATES_FILE_PATH = "/mnt"


class DownloadError(Exception):
    """Exception raised when package download fails."""
    pass


# thanks, https://stackoverflow.com/questions/63782892
async def run_command(*args, **kwargs):
    """
    Run a command with subprocess such that we can run multiple
    concurrently.
    """
    # Create subprocess
    process = await asyncio.create_subprocess_exec(
        *args,
        # stdout must a pipe to be accessible as process.stdout
        stderr=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        **kwargs,
    )
    # Wait for the subprocess to finish
    stdout, stderr = await process.communicate()
    # Return retcode, stdout and stderr
    return (process.returncode, stdout.decode().strip(), stderr.decode().strip())


async def download_item(item, arch, targetdir):
    """
    Download something - a build or task (with koji) or an update
    (with bodhi).
    """
    print(f"Downloading item {item}")
    if item.isdigit():
        # this will be a task ID
        cmd = ("koji", "download-task", f"--arch={arch}", "--arch=noarch", item)
    elif item.startswith("FEDORA-"):
        # this is a Bodhi update ID
        cmd = ("bodhi", "updates", "download", "--arch", arch, "--updateid", item)
    else:
        # assume it's an NVR
        cmd = ("koji", "download-build", f"--arch={arch}", "--arch=noarch", item)
    # do the download and check for failure
    (retcode, _, stderr) = await run_command(*cmd, cwd=targetdir)
    if retcode:
        # "No .*available for {nvr}" indicates there are no
        # packages for this arch in the build
        if not f"available for {item}" in stderr:
            print(f"Downloading {item} failed: {stderr}")
            return item
    return False


async def create_workarounds_repo(workarounds, arch, config):
    """Set up the workarounds repository."""
    shutil.rmtree(WORKAROUNDS_DIR, ignore_errors=True)
    os.makedirs(WORKAROUNDS_DIR)
    rets = []
    if workarounds:
        for i in range(0, len(workarounds), 20):
            tasks = [
                asyncio.create_task(download_item(item, arch, WORKAROUNDS_DIR))
                for item in workarounds[i : i + 20]
            ]
            rets.extend(await asyncio.gather(*tasks))
    subprocess.run(["createrepo", "."], cwd=WORKAROUNDS_DIR, check=True)
    if config:
        with open("/etc/yum.repos.d/workarounds.repo", "w", encoding="utf-8") as repofh:
            repofh.write(
                "[workarounds]\nname=Workarounds repo\n"
                "baseurl=file:///mnt/workarounds_repo\n"
                "enabled=1\nmetadata_expire=1\ngpgcheck=0"
            )
    return [ret for ret in rets if ret]


async def create_updates_repo(items, arch, config):
    """Set up the updates/task repository."""
    # we do not recreate the directory as the test code has to do that
    # since it has to mount it, before we run
    rets = []
    for i in range(0, len(items), 20):
        tasks = [
            asyncio.create_task(download_item(item, arch, UPDATES_DIR))
            for item in items[i : i + 20]
        ]
        rets.extend(await asyncio.gather(*tasks))
    subprocess.run(["createrepo", "."], cwd=UPDATES_DIR, check=True)
    if not glob.glob(f"{UPDATES_DIR}/*.rpm"):
        pathlib.Path(f"{UPDATES_FILE_PATH}/updatepkgnames.txt").touch()
        pathlib.Path(f"{UPDATES_FILE_PATH}/updatepkgs.txt").touch()
    else:
        cmd = "rpm -qp *.rpm --qf '%{SOURCERPM} %{NAME} %{EPOCHNUM} %{VERSION} %{RELEASE}\n' | "
        cmd += f"sort -u > {UPDATES_FILE_PATH}/updatepkgs.txt"
        subprocess.run(cmd, shell=True, check=True, cwd=UPDATES_DIR)
        # also log just the binary package names: this is so we can check
        # later whether any package from the update *should* have been
        # installed, but was not
        subprocess.run(
            "rpm -qp *.rpm --qf '%{NAME} ' > "
            + f"{UPDATES_FILE_PATH}/updatepkgnames.txt",
            shell=True,
            check=True,
            cwd=UPDATES_DIR,
        )
    if config:
        with open("/etc/yum.repos.d/advisory.repo", "w", encoding="utf-8") as repofh:
            repofh.write(
                "[advisory]\nname=Advisory repo\nbaseurl=file:///mnt/update_repo\n"
                "enabled=1\nmetadata_expire=3600\ngpgcheck=0"
            )
    return [ret for ret in rets if ret]


def commalist(string):
    """Separate a string on commas."""
    return string.split(",")


def parse_args():
    """Parse CLI args with argparse."""
    parser = argparse.ArgumentParser(
        description="Packager downloader script for openQA tests"
    )
    parser.add_argument("arch", help="Architecture")
    parser.add_argument(
        "--workarounds",
        "-w",
        type=commalist,
        help="Comma-separated list of workaround packages",
    )
    parser.add_argument(
        "--updates",
        "-u",
        type=commalist,
        help="Comma-separated list of update/task packages",
    )
    parser.add_argument(
        "--configs", "-c", action="store_true", help="Write repo config files"
    )
    args = parser.parse_args()
    if not (args.workarounds or args.updates):
        parser.error("At least one of workarounds or updates package lists is required")
    return args


async def main():
    """Do the thing!"""
    args = parse_args()

    tasks = []
    if args.workarounds:
        tasks.append(
            asyncio.create_task(
                create_workarounds_repo(args.workarounds, args.arch, args.configs)
            )
        )
    if args.updates:
        tasks.append(
            asyncio.create_task(
                create_updates_repo(args.updates, args.arch, args.configs)
            )
        )
    failed = []
    rets = await asyncio.gather(*tasks, return_exceptions=True)
    for ret in rets:
        if isinstance(ret, Exception):
            raise ret
        failed.extend(ret)
    if failed:
        sys.exit(f"Download of item(s) {', '.join(failed)} failed!")


asyncio.run(main())
