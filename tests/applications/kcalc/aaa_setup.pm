use base "installedtest";
use strict;
use testapi;
use utils;

# This script starts the KCalc application
# and saves the milestone for the consequtive
# tests.

sub run {
    my $self = shift;
    # Run the application
    menu_launch_type("kcalc");
    assert_screen("kcalc_runs");
    # wait for system to settle before snapshotting
    sleep 10;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:

