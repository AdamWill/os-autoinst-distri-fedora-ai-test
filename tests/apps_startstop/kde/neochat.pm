use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Neochat starts.

sub run {
    my $self = shift;
    # Start the application
    menu_launch_type 'neochat';
    # Check that it is started
    assert_screen "apps_run_neochat";
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
