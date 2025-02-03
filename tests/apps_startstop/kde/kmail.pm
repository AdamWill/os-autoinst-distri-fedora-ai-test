use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Kmail starts.

sub run {
    my $self = shift;

    # Start the application
    menu_launch_type 'kmail';
    # The Kmail window is now covered with an account
    # creation dialogue. Let's get rid of it to be able
    # to assert the Kmail window again.
    if (check_screen("kmail_account_dialogue", timeout => 30)) {
        # Click on the exit icon
        assert_and_click("kde_exit_icon");
    }
    assert_screen("apps_run_kmail");

    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
