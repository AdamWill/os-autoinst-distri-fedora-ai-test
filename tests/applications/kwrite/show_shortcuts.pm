use base "installedtest";
use strict;
use testapi;
use utils;

# This part tests that Shortcuts can be shown.

sub run {
    my $self = shift;
    # wait for snapshot restore to settle
    sleep 5;
    # Click into the text to get focus
    if (check_screen("kwrite_menu_settings")) {
        click_lastmatch;
    }
    else {
        assert_and_click("kwrite_menu_settings");
    }

    # Open Shortcuts.
    assert_and_click("kwrite_submenu_settings");
    assert_and_click("kwrite_submenu_shortcuts");
    # Assert the screen and move to next one
    assert_screen "kwrite_shortcuts_shown";

    # Find a new window shortcut
    assert_and_click("kwrite_search_bar");
    type_very_safely("new window");
    assert_screen("kwrite_newwindow_shortcut_found");
}


sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
