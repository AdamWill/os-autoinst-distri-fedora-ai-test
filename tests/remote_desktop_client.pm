use base "installedtest";
use strict;
use testapi;
use utils;
use mmapi;
use lockapi;

# This test uses a Connections application to establish an
# RDP connection to a remote computer running Gnome Workstation.

sub run {
    my $self = shift;
    my $password = get_var("USER_PASSWORD", "weakpassword");
    my $rdpuser = "geralt";
    my $rdppass = "ciriofcintra";
    my $ip = "172.16.2.177";

    # Wait until the RDP server is ready
    # and lock parallel connection.
    mutex_lock("kaermorhen_opened");

    # Unlock the session if it has locked in the meantime.
    if (check_screen("panel_screen_locked")) {
        send_key("up");
        sleep(1);
        type_very_safely("$password\n");
    }

    # Open the Connections and start the connection.
    menu_launch_type("connections");
    wait_still_screen(3);
    assert_screen("connections_runs");
    assert_and_click("connections_nothanks");
    assert_and_click("connections_add_connection");
    type_very_safely($ip);
    assert_and_click("gnome_button_connect");

    # Log onto the system.
    assert_and_click("connection_verify");
    assert_and_click("connection_username");
    type_very_safely($rdpuser);
    send_key("tab");
    send_key("tab");
    type_very_safely($rdppass);
    assert_and_click("connection_authenticate");
    wait_still_screen(3);
    send_key("ret");
    type_very_safely("$password\n");
    wait_still_screen(2);

    # Start the terminal
    type_very_safely("terminal\n");
    wait_still_screen(3);

    # Check that we are on the correct computer.
    # We can tell from the terminal prompt.
    assert_screen("freerdp_desktop_connected");

    # Unlock the parallel connection
    mutex_unlock("karemorhen_opened");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}
1;
# vim: set sw=4 et:
