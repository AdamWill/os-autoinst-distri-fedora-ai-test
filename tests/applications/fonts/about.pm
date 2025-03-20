use base "installedtest";
use strict;
use testapi;
use utils;

# This script will examine that the About dialogue
# works as expected.

sub run {
    my $self = shift;
    # Click on the Info icon in the upper right corner.
    assert_and_click("gnome_icon_info");
    # Check that the correct font is shown.
    assert_screen("fonts_about_shown");
    # Click on Credits to see them.
    assert_and_click("gnome_selector_credits");

    # Check that Credits are shown
    assert_screen("fonts_credits_shown");
    # Return to previous screen
    send_key("esc");

    # Click on Legal to see legal info.
    assert_and_click("gnome_selector_legal");
    # Check that Credits are shown
    assert_screen("fonts_legal_shown");
    # Return to previous screen
    send_key("esc");

    # Check that a project website can be reached.
    assert_and_click("gnome_selector_website");
    # Check that the website has been opened
    assert_screen("fonts_website_opened");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
