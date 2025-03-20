use base "installedtest";
use strict;
use testapi;
use utils;

# This part tests if EoG can show the About window.

sub run {
    my $self = shift;

    # Open the menu
    send_key("f10");
    # Click on the About item
    assert_and_click("loupe_menu_about");
    assert_screen("loupe_about_shown");
    # Click on Credits
    assert_and_click("gnome_selector_credits");
    assert_screen("loupe_credits_shown");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
