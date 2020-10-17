use base "installedtest";
use strict;
use testapi;
use utils;
use i3;

sub run {
    if (!get_var("BOOTFROM")) {
        # If we are checking the desktop background on live, we will not get
        # _graphical_wait_login scheduled and need to boot ourselves.
        # On i3, we'll also get the firstlaunch wizard on auto-login and need to
        # ignore it for check_desktop. We then run the firstlaunch setup so that
        # the wizard window does not block the desktop background.
        do_bootloader(postinstall=>0);
        check_desktop(timeout => 120, no_firstlaunch_check => 1);
        firstlaunch_setup() if (get_var("DESKTOP") eq "i3");
    } else {
        check_desktop;
    }
    # If we want to check that there is a correct background used, as a part
    # of self identification test, we will do it here. For now we don't do
    # this for Rawhide as Rawhide doesn't have its own backgrounds and we
    # don't have any requirement for what background Rawhide uses.
    my $version = get_var('VERSION');
    my $rawrel = get_var('RAWREL');
    return unless ($version ne "Rawhide" && $version ne $rawrel);
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
