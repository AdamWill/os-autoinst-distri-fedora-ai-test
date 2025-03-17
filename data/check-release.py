#!/usr/bin/python3

# Copyright Red Hat
#
# This file is part of os-autoinst-distri-fedora.
#
# os-autoinst-distri-fedora is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author: Lukas Ruzicka <lruzicka@redhat.com>


"""
This script provides a simple test for Eof of Life dates on Fedora.
You can use it for two types of testing. The first test checks that
the SUPPORT_END value is at least a year ahead (in the time of testing),
which it should be. The second test checks if the End of Life date is
consisant across the three sources, the os-release file, Bodhi, and Fedora
Schedule.

When the test passes, it returns 0, otherwise there is one of the error codes.
"""


import argparse
import sys
from datetime import date, datetime, timedelta
import requests

VERBOSE = False
RESULT = 100


def cli():
    """Return the CLI arguments."""

    parser = argparse.ArgumentParser(
        description="Fedora '/etc/os-release' support date validator."
    )

    parser.add_argument(
        "--test",
        "-t",
        type=str,
        required=True,
        help="Test to perform [future, compare]",
    )

    parser.add_argument(
        "--release",
        "-r",
        type=str,
        required=False,
        help="Fedora release number (42, 43, ...)",
    )

    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Prints detailed info on the screen.",
    )

    args = parser.parse_args()
    return args


def log(*args, **kwargs):
    """Print out messages on CLI if VERBOSE."""
    if VERBOSE:
        print(*args, **kwargs)
    else:
        pass


def epochdate(epoch: int) -> date:
    """Return the date object calculated from the epoch integer."""
    converted = datetime.fromtimestamp(epoch)
    return converted.date()


def isodate(iso: str) -> date:
    """Return the date object calculated from the ISO format."""
    converted = date.fromisoformat(iso)
    return converted


def get_file_support() -> date:
    """Returns the support date from the os-release file."""
    with open("/etc/os-release", "r", encoding="utf-8") as release:
        lines = release.readlines()
        log("The /etc/os-release successfully read.")

    support_day = epochdate(0)
    for line in lines:
        if "SUPPORT_END" in line:
            _, value = line.split("=")
            value = value.strip()
    if value:
        support_day = isodate(value)
    return support_day


def support_date_in_future(eol: date) -> bool:
    """This function checks the support date from the os-release
    file, compares it with the current system date and tests if
    the os-release support date lies at least 12 months in the future."""

    # Get the necessary values from the operating system.
    today = datetime.today().date()
    log("Current date on tested system is:", today)
    tomorrow = today + timedelta(days=365)
    log("Minimal SUPPORT_END calculated from system time is:", tomorrow)
    log("Real /etc/os-release SUPPORT_END is:", eol)

    # Test if the support end date is in the future.
    result = False
    if eol >= tomorrow:
        log("Real SUPPORT_END is one year in the future.")
        result = 0
    else:
        log("Real SUPPORT_END is NOT one year in the future.")
        result = 1
    return result


def compare_eol_dates(release: int, eol: date) -> bool:
    """This function checks the support date on Fedora Schedule, Bodhi
    and the os-release file and compares them whether they are the same
    and fails if they are not."""
    log("The EOL date shown by the os-release file is:", eol.isoformat())
    # Get the Bodhi EOL date
    bodhi_response = requests.get(
        f"https://bodhi.fedoraproject.org/releases/F{release}", timeout=60
    )
    bodhi = bodhi_response.json()
    # Only convert the date if it is present, otherwise record 0.
    if bodhi["eol"]:
        bodhi_eol = isodate(bodhi["eol"])
    else:
        bodhi_eol = epochdate(0)
    log("The EOL date shown by Bodhi is:", bodhi_eol.isoformat())

    # Get the Schedule EOL date
    schedule_response = requests.get(
        f"https://fedorapeople.org/groups/schedule/f-{release}/"
        f"f-{release}-key.json",
        timeout=60,
    )
    schedule = schedule_response.json()
    tasks = schedule["tasks"][0]["tasks"][0]["tasks"]
    schedule_eol = epochdate(0)
    for task in tasks:
        if "End of Life" in task["name"]:
            schedule_eol = epochdate(int(task["end"]))
            break
    log("The EOL date shown by Fedora Schedule is:", schedule_eol.isoformat())

    # Compare the dates
    result = None
    if eol == bodhi_eol and eol == schedule_eol:
        log("All EOL dates have the same value.")
        result = 0
    elif eol == bodhi_eol:
        log("The os-release matches Bodhi but Fedora Schedule is different.")
        result = 1
    elif eol == schedule_eol:
        log("The os-release matches Fedora Schedule but Bodhi is different.")
        result = 2
    elif bodhi_eol == schedule_eol:
        log("Bodhi matches Fedora Schedule, but os-release is different.")
        result = 3
    else:
        log("All EOL dates have different values.")
        result = 4
    return result


arguments = cli()
VERBOSE = arguments.verbose
os_release_eol = get_file_support()

codebook = {
    100: "Something went terribly bad in the testing script.",
    1: "Fedora Schedule shows a different EOL value than other sources.",
    2: "Bodhi shows a different EOL value than other sources.",
    3: "The os-release file shows a different EOL value than other sources.",
    4: "All sources have a different EOL value.",
    5: "For this type of test, you need to use the --release option.",
}

if arguments.test == "compare":
    if not arguments.release:
        # No arguments, exit
        sys.exit(codebook[5])

    RESULT = compare_eol_dates(arguments.release, os_release_eol)
else:
    RESULT = support_date_in_future(os_release_eol)

if RESULT != 0:
    # Exit with an error message.
    log("Test failed.", codebook[RESULT])
    sys.exit(codebook[RESULT])
else:
    # Exit cleanly if result is 0
    log("Test passed.")
    sys.exit(0)
