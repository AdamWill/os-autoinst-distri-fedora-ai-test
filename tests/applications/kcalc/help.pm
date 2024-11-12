use base "installedtest";
use strict;
use testapi;
use utils;

# This script checks that Gnome Calculator shows help.

sub run {
    my $self = shift;
    # Wait until everything settles.
    sleep 5;
    # Open Help
    send_key("f1");
    wait_still_screen(2);

    # Check that Help opens.
    assert_screen("kcalc_help_shown");

    # Rest of the documentation is currently
    # unavailable.
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:

