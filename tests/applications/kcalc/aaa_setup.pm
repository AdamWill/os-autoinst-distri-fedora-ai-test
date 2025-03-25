use base "installedtest";
use strict;
use testapi;
use utils;

# This script starts the KCalc application
# and saves the milestone for the following
# tests.

sub run {
    my $self = shift;
    kde_doublek_workaround();
    # Run the application
    menu_launch_type("kcalc", checkstart => 1);
    # wait for system to settle before snapshotting
    sleep 10;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:

