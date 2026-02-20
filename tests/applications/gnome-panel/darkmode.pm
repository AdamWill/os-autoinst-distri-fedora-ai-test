use base "installedtest";
use strict;
use testapi;
use utils;

# This part of the suite tests if dark mode can
# be toggled using the Panel controls.

# This subroutine tries to find out to which version
# the existing background belongs. At first, it will check
# if the background is the latest background (needle exists),
# if not, it checks if it is the one before last or even the
# two before last.
#
# The purpose of this is not to check if the version
# has correct background, so we will not fail
# if we can still find at least one plausible to
# see if Darkmode can be toggled.
sub inspect_background {
    my $version = get_var('VERSION');
    my $older;
    my $oldest;
    unless ($version eq 'eln') {
        $version = get_release_number();
        $older = $version - 1;
        $oldest = $version - 2;
    }
    # If the background matches the version, return it.
    if (check_screen("${version}_background")) {
        return $version;
    }
    # If we are here, check for the older background.
    elsif ($older && check_screen("${older}_background")) {
        return $older;
    }
    elsif ($oldest && check_screen("${oldest}_background")) {
        record_soft_failure("The background version seems to be two versions old.");
        return $oldest;
    }
    else {
        die("The background image is different from what we expect.");
    }
}

sub run {
    my $self = shift;
    # Check that standard background is active
    my $version = inspect_background();
    # Open panel controls and switch to dark mode.
    assert_and_click("panel_controls");
    assert_and_click("panel_ctrl_darkmode");
    send_key("esc");
    # Check it has changed to dark mode.
    assert_screen("${version}_background_dark");
    # Open panel controls and switch to light mode.
    assert_and_click("panel_controls");
    assert_and_click("panel_ctrl_darkmode");
    send_key("esc");
    # Check it has changed to light mode.
    assert_screen("${version}_background");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
