use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Firewall starts.

sub run {
    my $self = shift;
    my $password = get_var('ROOT_PASSWORD', 'weakpassword');

    # Start the application
    menu_launch_type 'firewall';
    # Firewall requires password to be entered and confirmed to start.
    # View password
    authenticate($password, timeout => 60, stillscreen => 3);

    # Check that it is started
    assert_screen 'apps_run_firewall';
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
