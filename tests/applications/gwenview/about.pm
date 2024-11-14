use base "installedtest";
use strict;
use testapi;
use utils;

# This part tests if EoG can show the About window.

sub run {
    my $self = shift;

    # Open the menu
    assert_and_click("gwen_burger_menu");
    # Click to open the About item
    assert_and_click("gwen_submenu_help");
    assert_and_click("gwen_submenu_about");
    assert_screen("gwen_about_shown");
    # Click on Credits
    assert_and_click("gwen_about_credits");
    assert_screen("gwen_credits_shown");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
