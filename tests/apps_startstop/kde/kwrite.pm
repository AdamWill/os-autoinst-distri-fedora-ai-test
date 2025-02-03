use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Kwrite starts.

sub run {
    my $self = shift;

    # Start the application
    menu_launch_type 'kwrite';
    # Check that it is started
    assert_screen 'apps_run_kwrite', timeout => 60;
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
