use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Kontact starts.

sub run {
    my $self = shift;

    # Start the application
    menu_launch_type 'kontact';
    # Similar to Kmail, we have the same dialogue
    # covering the application. Let's get rid of it, too.
    if (check_screen("kmail_account_dialogue", timeout => 30)) {
        # Click on the exit icon
        assert_and_click("kde_exit_icon");
    }
    # Check that the application window is there.
    assert_screen 'apps_run_kontact';
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
