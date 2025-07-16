use base "installedtest";
use strict;
use testapi;
use utils;

# This part of the suite Tests that the middle part
# of the panel works, with the date and time.

sub run {
    my $self = shift;
    # Click on the datetime part to see the details.
    assert_and_click("panel_datetime");
    # Check that Calendar is shown.
    assert_screen("panel_calendar_shown");

    # Check that when we click on Today,
    # Gnome Calendar will be opened - but not on Silverblue:
    # https://github.com/fedora-silverblue/issue-tracker/issues/448
    unless (get_var("CANNED")) {
        assert_and_click("panel_area_today");
        assert_screen("apps_run_calendar");
        send_key("alt-f4");
        wait_still_screen(2);
        assert_and_click("panel_datetime");
    }

    # Check that when we click on World Clocks area
    # the clock application will be shown.
    assert_and_click("panel_add_world_clocks");
    assert_screen(["apps_run_clocks", "grant_access"]);
    # sometimes we match apps_run_clocks for a split second before
    # grant_access appears, so handle that
    wait_still_screen 3;
    assert_screen(["apps_run_clocks", "grant_access"]);
    click_lastmatch;
    if (match_has_tag("grant_access")) {
        assert_and_click("apps_run_clocks");
    }
    send_key("alt-f4");
    wait_still_screen(2);
    #
    # Check that if we click on Select weather location
    # the Weather app will start.
    assert_and_click("panel_datetime");
    assert_and_click("panel_select_weather_location");
    assert_screen(["apps_run_weather", "grant_access"]);
    # sometimes we match apps_run_weather for a split second before
    # grant_access appears, so handle that
    wait_still_screen 3;
    assert_screen(["apps_run_weather", "grant_access"]);
    click_lastmatch;
    if (match_has_tag("grant_access")) {
        assert_and_click("apps_run_weather");
    }
    send_key("alt-f4");
    wait_still_screen(2);
    # Check that if we click on Do not disturb,
    # the slider moves and a silent regime indicator
    # appears on the top panel.
    assert_and_click("panel_datetime");
    assert_screen("panel_panel_shown");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
