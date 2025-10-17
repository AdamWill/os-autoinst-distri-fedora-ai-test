use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that ABRT starts.

sub run {
    my $self = shift;
    # Start the application
    # typing 'abrt' prefers Partition Manager for some reason,
    # so we have to skip checkstart
    menu_launch_type('problem', checkstart => 0);
    assert_screen("apps_run_abrt");
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
