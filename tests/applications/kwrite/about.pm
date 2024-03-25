use base "installedtest";
use strict;
use testapi;
use utils;

# This part tests that About can be displayed.

sub run {
    my $self = shift;
    # Open the menu.
    assert_and_click("kde_mainmenu_help");
    wait_still_screen(2);

    # Choose the About item.
    assert_and_click "kwrite_submenu_about";
    wait_still_screen(2);

    # Check that the About dialogue was opened.
    assert_screen "kwrite_about_shown";

    # Click on Credits to move to another screen.
    assert_and_click "kwrite_credits";
    wait_still_screen(2);

    # Check that Credits were shown.
    assert_screen "kwrite_credits_shown";
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
