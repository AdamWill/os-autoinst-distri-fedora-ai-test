use base "installedtest";
use strict;
use testapi;
use utils;

# This part tests that we can do line numbering,
# line navigation, line highlighting and show side and bottom panels.

sub open_settings_or_preferences {
    # the 'settings menu' was removed in 48 and merged into preferences
    # but the flatpak is still 47 for now so we need to handle both
    if (check_screen("gte_settings_button", 3)) {
        click_lastmatch;
    }
    else {
        assert_and_click("gnome_burger_menu");
        assert_and_click("gte_preferences_submenu");
    }
}

sub run {
    my $self = shift;

    # Switches on line numbering.
    open_settings_or_preferences;
    wait_still_screen(3);
    assert_and_click("gte_display_line_numbers");
    # for the preferences case
    send_key("esc");
    assert_screen("gte_lines_numbered");

    # Highlights the current line.
    # Use the menu to switch on highlighting.
    assert_and_click("gnome_burger_menu");
    assert_and_click("gte_preferences_submenu");
    # This fixes a problem where on smaller screens
    # some options are hidden and we need to scroll
    # to see them.
    send_key_until_needlematch("gte_toggle_line_highlight", "tab", 20);
    assert_and_click("gte_toggle_line_highlight");
    # Dismiss the menu
    send_key("esc");
    # Assert that it worked.
    assert_screen("gte_line_highlighted");

    # Displays the right margin.
    open_settings_or_preferences;
    send_key_until_needlematch("gte_display_margin", "tab", 20);
    assert_and_click("gte_display_margin");
    # for the preferences case
    send_key("esc");
    assert_screen("gte_margin_displayed");

    # Display the side panel.
    assert_and_click("gnome_burger_menu");
    assert_and_click("gte_preferences_submenu");
    send_key_until_needlematch("gte_toggle_side_panel", "tab", 20);
    assert_and_click("gte_toggle_side_panel");
    send_key("esc");
    assert_screen("gte_side_panel_on");

    # Display the grid
    # this was removed in 48, use presence of settings button as proxy
    if (check_screen("gte_settings_button", 3)) {
        assert_and_click("gnome_burger_menu");
        assert_and_click("gte_preferences_submenu");
        send_key_until_needlematch("gte_toggle_grid", "tab", 20);
        assert_and_click("gte_toggle_grid");
        send_key("esc");
        assert_screen("gte_grid_on");
    }
}


sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
