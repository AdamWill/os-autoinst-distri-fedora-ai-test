use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Konsole starts.

sub run {
    my $self = shift;

    # Start the application
    # we don't use desktop_launch_terminal here as we specifically
    # want to run 'konsole' from the kicker menu in this test
    menu_launch_type 'konsole';
    # Check that it is started
    assert_screen 'apps_run_konsole', timeout => 60;
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
