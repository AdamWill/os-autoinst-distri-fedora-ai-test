#!/usr/bin/python3

"""Dumb script for staging an old needle cleanup.

First, log in to the stg server (always use stg because some needles may
only be used on Power) and do this:
    psql -h db-openqa01.iad2.fedoraproject.org -U openqastg -d openqa-stg -W
and enter the password (from /etc/openqa/database.ini). Now do this,
changing the date in the `select` command to an appropriate one - a few
months before the current date:
    \o oldneedles.txt
    select filename from needles where date_trunc('day', last_matched_time) < '2023-01-01' or last_matched_time is null;
    ctrl-d (to quit)
now copy oldneedles.txt off the server, and run this script on it. It will
stage a git commit that removes all the identified needles.
"""

import datetime
import os
import subprocess
import sys

try:
    fname = sys.argv[1]
except IndexError:
    sys.exit("You must pass the file with the query output as the argument!")

with open(fname, "r", encoding="utf-8") as fh:
    lines = fh.readlines()

# strip the column name and underlines
lines = lines[2:]

# needles we know we want to keep around: these are ones that are
# encountered very rarely, but which *do* have a legitimate reason
# to exist. often the exact needle we have would not match any more
# anyway, but keeping it around prevents check-needles.py from
# complaining, and gives us a template to create a working needle
# from the next time we encounter the rare situation
keeplist = (
    # 'system crashes to emergency mode / dracut' cases
    "emergency_rescue_nopassword",
    "root_logged_in-dracut",
    # text install just doesn't fail this way very often
    "anaconda_main_hub_text_unfinished",
    # upgrade tests don't fail on system-upgrade reboot very often
    "upgrade_fail",
    # text install just doesn't fail very often
    "anaconda_text_error",
    # weather conditions can vary!
    "weather_icon",
    # this needle shows the details when Software has a problem
    # which does not happen very often
    "software_button_details",
)

changed = False
for line in lines:
    # query output lines start with a space, when we hit one that does
    # not, we've done all the query output lines and can quit
    if not line.startswith(" "):
        break
    line = line.strip()
    if any(keep in line for keep in keeplist):
        continue
    line = f"needles/{line}"
    # the db has needles we deleted before in it, so let's not bother
    # trying to remove them again
    if os.path.exists(line):
        basename = line[:-4]
        command = ("git", "rm", f"{basename}json", f"{basename}png")
        subprocess.run(command)
        changed = True

# create the commit
if changed:
    today = datetime.date.today().strftime("%Y-%m-%d")
    command = ("git", "commit", "-a", "-s", "-m", f"Old needle cleanup {today}")
    subprocess.run(command)
else:
    print("Nothing to do!")
    sys.exit()
