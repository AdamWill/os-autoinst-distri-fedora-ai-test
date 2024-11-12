use base "installedtest";
use strict;
use testapi;
use utils;

# This script checks that Gnome Calculator shows About.

sub run {
    my $self = shift;
    # Let's wait until everything settles down properly
    # before we start testing.
    sleep 5;
    # Open the menu and click on the About item.
    assert_and_click("kde_mainmenu_help");
    wait_still_screen(2);
    assert_and_click("kcalc_submenu_about");
    # Check that it is shown.
    assert_screen("kcalc_about_shown");
    # Click on the Credits button and check that it shows.
    assert_and_click("kcalc_authors");
    assert_screen("kcalc_authors_shown");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:

