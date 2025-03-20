use base "installedtest";
use strict;
use testapi;
use utils;

# This script will show info for the Adwaita Sans font
# that should be the among those installed by default.

sub run {
    my $self = shift;
    # Send the TAB key until the Adwaita Sans font is found.
    send_key_until_needlematch("fonts_adwaita_font", "tab", 30, 1);
    # Click on the icon
    click_lastmatch();
    # Check that the correct font is shown.
    assert_screen("fonts_adwaita_shown");
    # Check that various sizes are shown.
    assert_screen("fonts_adwaita_sizes");
    # Click on Info to get more information.
    assert_and_click("gnome_button_info");
    # Check for various information on that page.
    assert_screen("fonts_adwaita_info");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
