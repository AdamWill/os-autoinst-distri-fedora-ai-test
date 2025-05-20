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

"""This is an openQA template loader/converter for FIF, the Fedora Intermediate Format. It reads
from one or more files expected to contain FIF JSON-formatted template data; read on for details
on this format as it compares to the upstream format. It produces data in the upstream format; it
can write this data to a JSON file and/or call the upstream loader on it directly, depending on
the command-line arguments specified.

The input data must contain definitions of Machines, Products, TestSuites, and Profiles. It may
also contain Flavors, ProductDefaults and ProfileGroups. It also *may* contain JobTemplates, but
is expected to contain none or only a few oddballs.

The format for Machines, Products and TestSuites is based on the upstream format but with various
quality-of-life improvements. Upstream, each of these is a list-of-dicts, each dict containing a
'name' key. This loader expects each to be a dict-of-dicts, with the names as keys (this is both
easier to read and easier to access). In the upstream format, each Machine, Product and TestSuite
dict can contain an entry with the key 'settings' which defines variables. The value (for some
reason...) is a list of dicts, each dict of the format {"key": keyname, "value": value}. This
loader expects a more obvious and simple format where the value of the 'settings' key is simply a
dict of keys and values. With this loader, Products can inherit settings from Flavors to reduce
duplication - see below.

The expected format of the Flavors dict is a dict-of-dicts. For each entry, the key is a flavor
name that is expected to be used as the 'flavor' for one or more Product(s). The value is a dict
with only a 'settings' key, containing settings in the same format described above. When
processing Products, fifloader will merge in the settings from the product's flavor, if it
exists in the Flavors dict and defines any settings. If both the Product and the Flavor define
a given setting, the Product's definition wins. The purpose of the Flavors dict is to reduce
duplication of settings between multiple products with the same flavor.

The ProductDefaults dict contains default values for Products. Any key/value pair in this dict
will be merged into every Product in the *same file*. Conflicts are resolved in favor of the
Product, naturally. Note that this merge happens *before* the file merge, so ProductDefaults are
*per file*, they are not merged from multiple input files as described below.

The expected format of the Profiles dict is a dict-of-dicts. For each entry, the key is a unique
name, and the value is a dict with keys 'machine' and 'product', each value being a valid name from
the Machines or Products dict respectively. The name of each profile can be anything as long as
it's unique.

The expected format of the ProfileGroups dict is a dict-of-dicts. For each entry, the key is the
name of a "profile group". The value is a dict whose keys are profile names or profile group
names and whose values are priority numbers. As the name implies a profile group is just a group of
profiles; the idea is to allow test suites to specify sets of profiles that commonly go together
without having to constantly repeat them. Profile groups can be nested - a profile group can
contain a reference to another profile group. Any level of recursion is fine so long as there is
no loop (the loader will detect loops and exit with an error).

For TestSuites, this loader then expects at least a 'profiles' key or a 'profile_groups' key in
each dict (having both is fine). The value of 'profiles' is a dict indicating the Profiles from
which we should generate one or more job templates for that test suite. For each entry in the dict,
the key is a profile name from the Profiles dict, and the value is the priority to give the
generated job template. The value of 'profile_groups' is a similar dict, except the keys are
names of profile groups rather than profiles. When using profile groups, the priority value given
in the profile group is added to the value given in the profile_groups dict to produce a total
priority. Effectively this means the priority value given in the test suite is the base priority
for the whole group, and the priority values in the profile group should be used to adjust that
base priority for the relative importance of the profiles within the group; the values in the
group may well all be 0.

This loader will generate JobTemplates from the combination of TestSuites and Profiles. It means
that, for instance, if you want to add a new test suite and run it on the same set of images and
arches as several other tests are already run, you do not need to do a large amount of copying and
pasting to create a bunch of JobTemplates that look a lot like other existing JobTemplates but with
a different test_suite value; you can just specify an appropriate profiles dict, which is much
shorter and easier and less error-prone. Thus specifying JobTemplates directly is not usually
needed and is expected to be used only for some oddball case which the generation system does not
handle.

The loader will automatically set the group_name for each job template based on Fedora-specific
logic which we previously followed manually when creating job templates (e.g. it is set to 'Fedora
PowerPC' for compose tests run on the PowerPC arch); thus this loader is not really generic but
specific to Fedora conventions. This could possibly be changed (e.g. by allowing the logic for
deciding group names to be configurable) if anyone else wants to use it.

Multiple input files will be combined. Mostly this involves simply updating dicts, but there is
special handling for TestSuites to allow multiple input files to each include entries for 'the
same' test suite, but with different profile dicts. So for instance one input file may contain a
complete TestSuite definition, with the value of its `profiles` key as `{'foo': 10}`. Another input
file may contain a TestSuite entry with the same key (name) as the complete definition in the other
file, and the value as a dict with only a `profiles` key (with the value `{'bar': 20}`). This
loader will combine those into a single complete TestSuite entry with the `profiles` value
`{'foo': 10, 'bar': 20}`. As noted above, ProductDefaults are *not* merged in this way.
"""

import argparse
import json
import os
import subprocess
import sys

import jsonschema

SCHEMAPATH = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'schemas')

def schema_validate(instance, fif=True, state='complete', schemapath=SCHEMAPATH):
    """Validate some input against one of our JSON schemas. We have
    'complete' and 'incomplete' schemas for FIF and the upstream
    template format. The 'complete' schemas expect the validated
    input to contain a complete set of data (everything needed for
    an openQA deployment to actually run tests). The 'incomplete'
    schemas expect the validated input to contain at least *some*
    valid data - they are intended for validating input files which
    will be combined into 'complete' data, or which will be loaded
    without --clean, to add to an existing configuration.
    """
    filename = 'openqa-'
    if fif:
        filename = 'fif-'
    filename += state
    filename += '.json'
    base_uri = "file://{0}/".format(schemapath)
    resolver = jsonschema.RefResolver(base_uri, None)
    schemafile = os.path.join(schemapath, filename)
    with open(schemafile, 'r') as schemafh:
        schema = json.load(schemafh)
    # raises an exception if it fails
    jsonschema.validate(instance=instance, schema=schema, resolver=resolver)
    return True

# you could refactor this just using a couple of dicts, but I don't
# think that would really make it *better*
# pylint:disable=too-many-locals, too-many-branches
def merge_inputs(inputs, validate=False, clean=False):
    """Merge multiple input files. Expects JSON file names. Optionally
    validates the input files before merging, and the merged output.
    Returns a 6-tuple of machines, flavors, products, profiles,
    testsuites and jobtemplates (the first five as dicts, the last as a
    list).
    """
    machines = {}
    flavors = {}
    products = {}
    profiles = {}
    pgroups = {}
    testsuites = {}
    jobtemplates = []

    for _input in inputs:
        try:
            with open(_input, 'r') as inputfh:
                data = json.load(inputfh)
        # we're just wrapping the exception a bit, so this is fine
        # pylint:disable=broad-except
        except Exception as err:
            print("Reading input file {} failed!".format(_input))
            sys.exit(str(err))
        # validate against pre-products-merge schema
        if validate:
            schema_validate(data, fif=True, state="predefault")
        for (pname, product) in data["Products"].items():
            temp = dict(data.get("ProductDefaults", {}))
            temp.update(product)
            data["Products"][pname] = temp
        # validate against incomplete schema
        if validate:
            schema_validate(data, fif=True, state="incomplete")

        # simple merges for all these
        for (datatype, tgt) in (
                ('Machines', machines),
                ('Flavors', flavors),
                ('Products', products),
                ('Profiles', profiles),
                ('ProfileGroups', pgroups),
                ('JobTemplates', jobtemplates),
        ):
            if datatype in data:
                if datatype == 'JobTemplates':
                    tgt.extend(data[datatype])
                else:
                    tgt.update(data[datatype])
        # special testsuite merging as described in the docstring
        if 'TestSuites' in data:
            for (name, newsuite) in data['TestSuites'].items():
                try:
                    existing = testsuites[name]
                    # copy, combine and stash the profiles and groups
                    combinedprofiles = dict(existing.get('profiles', {}))
                    combinedprofiles.update(newsuite.get('profiles', {}))
                    combinedpgroups = dict(existing.get('profile_groups', {}))
                    combinedpgroups.update(newsuite.get('profile_groups', {}))
                    # now update the existing suite with the new one, this
                    # will overwrite the profiles and groups
                    existing.update(newsuite)
                    # now restore the combined profiles and groups
                    if combinedprofiles:
                        existing['profiles'] = combinedprofiles
                    if combinedpgroups:
                        existing['profile_groups'] = combinedpgroups
                except KeyError:
                    testsuites[name] = newsuite

    # validate combined data, against complete schema if clean is True
    # (as we'd expect data to be loaded with --clean to be complete),
    # incomplete schema otherwise
    if validate:
        merged = {}
        if machines:
            merged['Machines'] = machines
        if flavors:
            merged['Flavors'] = flavors
        if products:
            merged['Products'] = products
        if profiles:
            merged['Profiles'] = profiles
        if pgroups:
            merged['ProfileGroups'] = pgroups
        if testsuites:
            merged['TestSuites'] = testsuites
        if jobtemplates:
            merged['JobTemplates'] = jobtemplates
        state = "incomplete"
        if clean:
            state = "complete"
        schema_validate(merged, fif=True, state=state)
        print("Input template data is valid")

    return (machines, flavors, products, profiles, pgroups, testsuites, jobtemplates)

def recurse_pgroup(pgroup, baseprio, pgroups, seen):
    """Recursion handler allowing nested profile groups. Takes the
    top-level profile group name and priority, the full ProfileGroups
    dict, and a set for infinite recursion checking.
    """
    profiles = {}
    for (item, prio) in pgroups[pgroup].items():
        if item in seen:
            sys.exit(f"Infinite recursion between profile groups {pgroup} and {item}")
        seen.add(item)
        if item in pgroups:
            profiles.update(recurse_pgroup(item, prio+baseprio, pgroups, seen))
        else:
            profiles[item] = prio+baseprio
    return profiles

def generate_job_templates(products, profiles, pgroups, testsuites):
    """Given machines, products, profiles and testsuites (after
    merging and handling of flavors, but still in intermediate format),
    generates job templates and returns them as a list.
    """
    jobtemplates = []
    for (name, suite) in testsuites.items():
        suiteprofs = {}
        for (pgroup, baseprio) in suite.get('profile_groups', {}).items():
            suiteprofs.update(recurse_pgroup(pgroup, baseprio, pgroups, set()))
        suiteprofs.update(suite.get('profiles', {}))
        if not suiteprofs:
            print("Warning: no profiles for test suite {}".format(name))
            continue
        for (profile, prio) in suiteprofs.items():
            jobtemplate = {'test_suite_name': name, 'prio': prio}
            # x86_64 compose
            jobtemplate['group_name'] = 'fedora'
            jobtemplate['machine_name'] = profiles[profile]['machine']
            product = products[profiles[profile]['product']]
            jobtemplate['arch'] = product['arch']
            jobtemplate['flavor'] = product['flavor']
            jobtemplate['distri'] = product['distri']
            jobtemplate['version'] = product['version']
            if jobtemplate['machine_name'] == 'ppc64le':
                if 'updates' in product['flavor']:
                    jobtemplate['group_name'] = "Fedora PowerPC Updates"
                else:
                    jobtemplate['group_name'] = "Fedora PowerPC"
            elif jobtemplate['machine_name'] in ('aarch64', 'ARM'):
                if 'updates' in product['flavor']:
                    jobtemplate['group_name'] = "Fedora AArch64 Updates"
                else:
                    jobtemplate['group_name'] = "Fedora AArch64"
            elif 'updates' in product['flavor']:
                # x86_64 updates
                jobtemplate['group_name'] = "Fedora Updates"
            jobtemplates.append(jobtemplate)
    return jobtemplates

def reverse_qol(machines, flavors, products, testsuites):
    """Reverse all our quality-of-life improvements in Machines,
    Flavors, Products and TestSuites. We don't do profiles as only
    this loader uses them, upstream loader does not. We don't do
    jobtemplates as we don't do any QOL stuff for that. Returns
    machines, products and testsuites - flavors are a loader-only
    concept.
    """
    # first, some nested convenience functions
    def to_list_of_dicts(datadict):
        """Convert our nice dicts to upstream's stupid list-of-dicts-with
        -name-keys.
        """
        converted = []
        for (name, item) in datadict.items():
            item['name'] = name
            converted.append(item)
        return converted

    def dumb_settings(settdict):
        """Convert our sensible settings dicts to upstream's weird-ass
        list-of-dicts format.
        """
        converted = []
        for (key, value) in settdict.items():
            converted.append({'key': key, 'value': value})
        return converted

    # merge flavors into products
    for product in products.values():
        flavsets = flavors.get(product["flavor"], {}).get("settings", {})
        if flavsets:
            temp = dict(flavsets)
            temp.update(product.get("settings", {}))
            product["settings"] = temp

    # drop profiles and groups from test suites - these are only used
    # for job template generation and should not be in final output.
    # if suite *only* contained profiles/groups, drop it
    for suite in testsuites.values():
        for prop in ('profiles', 'profile_groups'):
            if prop in suite:
                del suite[prop]
    testsuites = {name: suite for (name, suite) in testsuites.items() if suite}

    machines = to_list_of_dicts(machines)
    products = to_list_of_dicts(products)
    testsuites = to_list_of_dicts(testsuites)
    for datatype in (machines, products, testsuites):
        for item in datatype:
            if 'settings' in item:
                item['settings'] = dumb_settings(item['settings'])

    return (machines, products, testsuites)

def parse_args(args):
    """Parse arguments with argparse."""
    parser = argparse.ArgumentParser(description=(
        "Alternative openQA template loader/generator, using a more "
        "convenient input format. See docstring for details. "))
    parser.add_argument(
        '-l', '--load', help="Load the generated templates into openQA.",
        action='store_true')
    parser.add_argument(
        '--loader', help="Loader to use with --load",
        default="/usr/share/openqa/script/load_templates")
    parser.add_argument(
        '-w', '--write', help="Write the generated templates in JSON "
        "format.", action='store_true')
    parser.add_argument(
        '--filename', help="Filename to write with --write",
        default="generated.json")
    parser.add_argument(
        '--host', help="If specified with --load, gives a host "
        "to load the templates to. Is passed unmodified to upstream "
        "loader.")
    parser.add_argument(
        '-c', '--clean', help="If specified with --load, passed to "
        "upstream loader and behaves as documented there.",
        action='store_true')
    parser.add_argument(
        '-u', '--update', help="If specified with --load, passed to "
        "upstream loader and behaves as documented there.",
        action='store_true')
    parser.add_argument(
        '--no-validate', help="Do not do schema validation on input "
        "or output data", action='store_false', dest='validate')
    parser.add_argument(
        'files', help="Input JSON files", nargs='+')
    return parser.parse_args(args)

def run(args):
    """Read in arguments and run the appropriate steps."""
    args = parse_args(args)
    if not args.validate and not args.write and not args.load:
        sys.exit("--no-validate specified and neither --write nor --load specified! Doing nothing.")
    (machines, flavors, products, profiles, pgroups, testsuites, jobtemplates) = merge_inputs(
        args.files, validate=args.validate, clean=args.clean)
    jobtemplates.extend(generate_job_templates(products, profiles, pgroups, testsuites))
    (machines, products, testsuites) = reverse_qol(machines, flavors, products, testsuites)
    # now produce the output in upstream-compatible format
    out = {}
    if jobtemplates:
        out['JobTemplates'] = jobtemplates
    if machines:
        out['Machines'] = machines
    if products:
        out['Products'] = products
    if testsuites:
        out['TestSuites'] = testsuites
    if args.validate:
        # validate generated data against upstream schema
        state = "incomplete"
        if args.clean:
            state = "complete"
        schema_validate(out, fif=False, state=state)
        print("Generated template data is valid")
    if args.write:
        # write generated output to given filename
        with open(args.filename, 'w') as outfh:
            json.dump(out, outfh, indent=4)
    if args.load:
        # load generated output with given loader (defaults to
        # /usr/share/openqa/script/load_templates)
        loadargs = [args.loader]
        if args.host:
            loadargs.extend(['--host', args.host])
        if args.clean:
            loadargs.append('--clean')
        if args.update:
            loadargs.append('--update')
        loadargs.append('-')
        tries = 20
        while True:
            try:
                subprocess.run(loadargs, input=json.dumps(out), text=True, check=True)
                break
            except subprocess.CalledProcessError:
                if tries:
                    print(f"loader failed! retrying ({tries} attempts remaining)")
                    tries -= 1
                else:
                    sys.exit("loader failed and all retries exhausted!")

def main():
    """Main loop."""
    try:
        run(args=sys.argv[1:])
    except KeyboardInterrupt:
        sys.stderr.write("Interrupted, exiting...\n")
        sys.exit(1)

if __name__ == '__main__':
    main()

# vim: set textwidth=100 ts=8 et sw=4:
