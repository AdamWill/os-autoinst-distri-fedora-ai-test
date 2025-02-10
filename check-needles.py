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
# Author: Adam Williamson <awilliam@redhat.com>

"""This is a check script which checks for:

1. Unused needles - if none of the tags a needle declares is referenced
in the tests, it is considered unused.
2. Tag assertions with no needle - if a test seems to be asserting or
checking for a tag, but there is no needle with that tag. The code to
decide what string literals in the tests are tags is not perfect. If
a literal that *is* a tag is not being counted as one, you may need to
rejig the code, or add `# testtag` to the end of the line to cue this
script to consider it a tag. If a tag does not have a - or _ in it, it
must be added to the `knowns` list.
3. Image files in the needles directory with no matching JSON file.
4. JSON files in the needles directory with no matching image file.
"""

import glob
import json
import os
import re
import sys

NEEDLEPATH = os.path.join(os.path.dirname(os.path.realpath(__file__)), "needles")
TESTSPATH = os.path.join(os.path.dirname(os.path.realpath(__file__)), "tests")
LIBPATH = os.path.join(os.path.dirname(os.path.realpath(__file__)), "lib")
# these don't account for escaping, but I don't think we're ever going
# to have an escaped quotation mark in a needle tag
DOUBLEQUOTERE = re.compile('"(.*?)"')
SINGLEQUOTERE = re.compile("'(.*?)'")

# first we're gonna build a big list of all string literals that look
# like they're needle tags
testpaths = glob.glob(f"{TESTSPATH}/**/*.pm", recursive=True)
testpaths.extend(glob.glob(f"{LIBPATH}/**/*.pm", recursive=True))
testtags = []
for testpath in testpaths:
    # skip if it's a symlink
    if os.path.islink(testpath):
        continue
    # otherwise, scan it for string literals
    with open(testpath, "r") as testfh:
        testlines = testfh.readlines()
    for line in testlines:
        # ignore comments
        if line.strip().startswith("#"):
            continue
        matchfuncs = (
            "assert_screen",
            "assert_and_click",
            "assert_and_dclick",
            "check_screen",
            "start_with_launcher",
            "send_key_until_needlematch",
            "# testtag"
        )
        for matchfunc in matchfuncs:
            if matchfunc == "# testtag" and matchfunc in line:
                # for the comment tag we should take all literals from
                # the whole line
                start = 0
            else:
                # for match functions we should only take literals
                # after the function name
                start = line.find(matchfunc)
            # fortunately `find` returns -1 for 'no match'
            if start > -1:
                matcharea = line[start:]
                if matchfunc == "send_key_until_needlematch":
                    # this needs some special handling - we need
                    # to leave out the key to press, which should
                    # come after the first comma
                    matcharea = matcharea.split(",")[0]
                for match in DOUBLEQUOTERE.finditer(matcharea):
                    testtags.append(match[1])
                for match in SINGLEQUOTERE.finditer(matcharea):
                    testtags.append(match[1])

# filter the list a bit for matches that aren't tags. Almost all our
# tags have a - or an _ in them, except a small number of weirdos;
# this filters out a lot of false matches (like keypresses)
knowns = ("_", "-", "bootloader", "browser", "firefox")
testtags = [tag for tag in testtags if
            tag and
            not tag.isdigit() and
            not tag.isupper() and
            any(known in tag for known in knowns)]

# keep this around for the tagnoneedle check later; we can't use
# the 'synthetic' tags in that check as some of them we know don't
# have needles (e.g. the range(30,100) background tags, most of those
# don't exist yet)
realtesttags = set(tag for tag in testtags if "$" not in tag)
# now let's do some whitelisting, for awkward cases where we know that
# we concatenate string literals and stuff
# versioned backgrounds and release IDs
for rel in range(30, 100):
    testtags.append(f"{rel}_background")
    testtags.append(f"{rel}_background_dark")
    testtags.append(f"version_{rel}_ident")
# anaconda id needles, using tell_source
for source in ("workstation", "generic", "server"):
    testtags.append(f"leftbar_{source}")
    testtags.append(f"topbar_{source}")
# keyboard layout switching, using desktop_switch_layout
for environment in ("anaconda", "gnome"):
    for layout in ("native", "ascii"):
        testtags.append(f"{environment}_layout_{layout}")
# package set selection, using get_var('PACKAGE_SET')
for pkgset in ("kde", "workstation", "minimal"):
    testtags.append(f"anaconda_{pkgset}_highlighted")
    testtags.append(f"anaconda_{pkgset}_selected")
# desktop_login stuff
for user in ("jack", "jim"):
    testtags.append(f"login_{user}")
    testtags.append(f"user_confirm_{user}")
# partitioning stuff, there's a bunch of this, all in anaconda.pm
# multiple things use this
for part in ("swap", "root", "efi", "boot", "bootefi", "home"):
    testtags.append(f"anaconda_part_select_{part}")
    testtags.append(f"anaconda_blivet_part_inactive_{part}")
# select_disks
for num in range(1, 10):
    testtags.append(f"anaconda_install_destination_select_disk_{num}")
# custom_scheme_select
for scheme in ("standard", "lvmthin", "btrfs", "lvm"):
    testtags.append(f"anaconda_part_scheme_{scheme}")
# custom_blivet_add_partition
for dtype in ("lvmvg", "lvmlv", "lvmthin", "raid"):
    testtags.append(f"anaconda_blivet_part_devicetype_{dtype}")
# these are in webui already...
for fsys in ("ext4", "xfs", "efi_filesystem", "biosboot"):
    testtags.append(f"anaconda_blivet_part_fs_{fsys}")
    testtags.append(f"anaconda_blivet_part_fs_{fsys}_selected")
    testtags.append(f"anaconda_webui_custom_fs_{fsys}")
# ...these aren't yet
for fsys in ("btrfs", "ppc_prep_boot", "swap"):
    testtags.append(f"anaconda_blivet_part_fs_{fsys}")
    testtags.append(f"anaconda_blivet_part_fs_{fsys}_selected")
# this is variable-y in custom_blivet_resize_partition but we only
# call it with 'GiB' (in disk_custom_blivet_resize_lvm.pm)
testtags.append("anaconda_blivet_size_unit_GiB")
# this is variable-y in custom_change_type but we only actually have
# one value
testtags.append("anaconda_part_device_type_raid")
# custom_change_fs
for fsys in ("xfs", "ext4"):
    testtags.append(f"anaconda_part_fs_{fsys}")
    testtags.append(f"anaconda_part_fs_{fsys}_selected")
# Needles for Help viewer
for section in ("desktop", "networking", "sound", "files", "user", "hardware",
                "accessibility", "tipstricks", "morehelp"):
    testtags.append(f"help_section_{section}")
    testtags.append(f"help_section_content_{section}")
# Needles for Calculator
for button in ("div", "divider", "zero", "one", "two", "three", "four", "five",
                "six","seven", "eight", "nine", "mod", "percent", "pi", "root",
                "square", "sub"):
    testtags.append(f"calc_button_{button}")
    testtags.append(f"kcalc_button_{button}")
for result in ("BokZw", "Czo4s", "O9qsL", "WIxiR", "b5y2B", "h7MfO", "qxuBK",
                "tWshx", "uC8Ul", "3LAG3"):
    testtags.append(f"calc_result_{result}")
    testtags.append(f"kcalc_result_{result}")
# Needles for Contacts
for hashname in ("jlJmL", "7XGzO", "ps61y", "OvXj~", "GqYOp", "VEFrP"):
    testtags.append(f"contacts_name_{hashname}")
    testtags.append(f"contacts_contact_listed_{hashname}")
    testtags.append(f"contacts_contact_existing_{hashname}")
    testtags.append(f"contacts_contact_doubled_{hashname}")
    testtags.append(f"contacts_contact_altered_{hashname}")
    testtags.append(f"contacts_contact_added_{hashname}")
for info in ("home", "personal", "work"):
    testtags.append(f"contacts_label_{info}")
# Needles for Maps
for location in ("vilnius", "denali", "wellington", "poysdorf", "pune"):
    testtags.append(f"maps_select_{location}")
    testtags.append(f"maps_found_{location}")
    testtags.append(f"maps_info_{location}")
# Needles for Gnome Panel
for percentage in ("zero", "fifty", "hundred"):
    testtags.append(f"panel_volume_bar_{percentage}")
    testtags.append(f"panel_volume_indicator_{percentage}")
# Needles for Disks
for number in ("one", "two", "three"):
    testtags.append(f"disks_partition_{number}_formatted")
    testtags.append(f"disks_partition_{number}_selected")
    testtags.append(f"disks_partition_mounted_{number}")
    testtags.append(f"disks_partition_identifier_{number}")
    testtags.append(f"disks_partition_select_{number}")
    testtags.append(f"disks_select_partition_{number}")
    testtags.append(f"disks_partition_formatted_{number}")
    testtags.append(f"disks_partition_identifier_{number}")
for name in ("primavolta",  "secondavolta",  "terciavolta",  "boot",  "root",  "home", "renamed"):
    testtags.append(f"disks_partition_created_{name}")
    testtags.append(f"disks_fstype_changed_{name}")
for typus in ("swap",  "ext4",  "xfs", "linuxroot"):
    testtags.append(f"disks_select_{typus}")
    testtags.append(f"disks_select_filesystem_{typus}")
    testtags.append(f"disks_parttype_changed_{typus}")
# Needles for konversation/neochat
for app in ("neochat", "konversation"):
    testtags.append(f"{app}_runs")
testtags.extend(("konversation_connect", "konversation_confirm_close"))
# variable-y in custom_change_device but we only have one value
testtags.append("anaconda_part_device_sda")
# For language needles
for lang in ("english", "russian", "chinese", "arabic", "japanese", "turkish", "french"):
    testtags.append(f"gis_lang_{lang}_select")
    testtags.append(f"gis_lang_{lang}_selected")
# for Anaconda help related needles.
testtags.extend(f"anaconda_help_{fsys}" for fsys in ('install_destination',
'installation_progress', 'keyboard_layout', 'language_support', 'network_host_name',
'root_password', 'select_packages', 'installation_source', 'time_date', 'user_creation',
'language_selection', 'language', 'summary_link'))
# for Gnome navigation test
for app in ("calculator", "clocks", "files", "terminal", "texteditor"):
    testtags.append(f"navigation_navibar_{app}")
testtags.append("navigation_terminal_fullscreen")
testtags.extend(f"anaconda_main_hub_{fsys}" for fsys in ('language_support', 'selec_packages',
'time_date', 'create_user','keyboard_layout'))
for selection in ("hide", "maximize", "restore"):
    testtags.append(f"calculator_context_{selection}")
# After the change to menu_launch_type, applications should be whitelisted here
# to prevent the unused needles warning in case of apps_run_<application>.
for app in ("focuswriter", "gvim"):
    testtags.append(f"apps_run_{app}")

# retcode tracker
ret = 0

# now let's scan our needles
unused = []
noimg = []
noneedle = []
needletags = set()

needlepaths = glob.glob(f"{NEEDLEPATH}/**/*.json", recursive=True)
for needlepath in needlepaths:
    # check we have a matching image file
    imgpath = needlepath.replace(".json", ".png")
    if not os.path.exists(imgpath):
        noimg.append(needlepath)
    with open(needlepath, "r") as needlefh:
        needlejson = json.load(needlefh)
    needletags.update(needlejson["tags"])
    if any(tag in testtags for tag in needlejson["tags"]):
        continue
    unused.append(needlepath)

# check for tags with no needle
tagnoneedle = realtesttags - needletags
# allowlist
# this is a weird one: we theoretically know this needle exists but we
# don't know what it looks like because the function has been broken
# as long as the test has existed. once
# https://gitlab.gnome.org/GNOME/gnome-font-viewer/-/issues/64 is
# fixed we can create this needle and drop this entry
tagnoneedle.discard("fonts_c059_installed")

# reverse check, for images without a needle file
imgpaths = glob.glob(f"{NEEDLEPATH}/**/*.png", recursive=True)
for imgpath in imgpaths:
    needlepath = imgpath.replace(".png", ".json")
    if not os.path.exists(needlepath):
        noneedle.append(imgpath)

if unused:
    ret += 1
    print("Unused needle(s) found!")
    for needle in unused:
        print(needle)

if noimg:
    ret += 2
    print("Needle(s) without image(s) found!")
    for needle in noimg:
        print(needle)

if noneedle:
    ret += 4
    print("Image(s) without needle(s) found!")
    for img in noneedle:
        print(img)

if tagnoneedle:
    ret += 8
    print("Tag(s) without needle(s) found!")
    for tag in tagnoneedle:
        print(tag)

sys.exit(ret)
