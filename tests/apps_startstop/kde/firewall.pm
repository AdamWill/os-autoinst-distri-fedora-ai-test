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
    assert_screen "auth_required", timeout => 60;
    wait_still_screen 3;
    # FIXME when https://github.com/firewalld/firewalld/issues/1328
    # is fixed, switch (back) to type_very_safely here
    type_safely $password;
    send_key 'ret';
    wait_still_screen 3;

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
