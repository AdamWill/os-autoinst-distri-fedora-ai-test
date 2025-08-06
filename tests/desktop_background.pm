use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    check_desktop;
    # If we want to check that there is a correct background used, as a part
    # of self identification test, we will do it here. For now we don't do
    # this for Rawhide as Rawhide doesn't have its own backgrounds and we
    # don't have any requirement for what background Rawhide uses.
    my $version = get_var('VERSION');
    my $rawrel = get_var('RAWREL');
    return unless ($version ne "Rawhide" && $version ne $rawrel);
    # temporary for f43 branching to pass during the branch phase
    # FIXME: Remove when branching has completed
    if ($version eq "43") {
        record_info("Short circuit", "The background is not tested for Fedora 43. We shall switch it back on when we have fully branched.");
        return;
    }
    # KDE shows a different version of the welcome center on major upgrades,
    # which breaks this test
    click_lastmatch if (get_var("DESKTOP") eq "kde" && get_var("ADVISORY_OR_TASK") && check_screen "kde_ok", 5);
    assert_screen "${version}_background";
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
