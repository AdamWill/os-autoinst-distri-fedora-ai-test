use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    # run connections
    menu_launch_type('Connections');
    # If we see the Welcome screen, dismiss it.
    if (check_screen("connections_welcome", timeout => 10)) {
        assert_and_click("connections_no_thanks");
    }
    # Add a connection
    assert_and_click("connections_add_connection");
    # Fill in the connection details
    type_very_safely("172.16.2.114");
    assert_and_click("connections_type_rdp");
    assert_and_click("connections_connect_button");

    # "Verify" connection.
    assert_screen("connections_verify_screen");
    assert_and_click("connections_verify_button");

    # Fill in credentials
    send_key("tab");
    type_very_safely("rapunzel");
    send_key("tab");
    sleep(1);
    send_key("tab");
    sleep(1);
    type_very_safely("towertop");
    assert_and_click("connections_authenticate_button");
    wait_still_screen(5);
    # Make connection full screen to comply with installation needles.
    assert_and_click("connections_fullscreen_toggle");

    # The connection should have been established, so let's
    # check for it.
    assert_screen("anaconda_select_install_lang");
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
