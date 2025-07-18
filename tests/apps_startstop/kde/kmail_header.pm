use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Kmail Header Edit starts.

sub run {
    my $self = shift;

    # Start the application
    menu_launch_type 'kmail header';
    # Check that the application runs
    assert_screen 'apps_run_kmail_hedit', timeout => 60;
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
