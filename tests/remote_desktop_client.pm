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
    my $rdpuser = get_var("RDP_USER", "geralt");
    my $rdppass = get_var("RDP_PASS", "ciriofcintra");
    my $ip = get_var("RDP_SERVER_IP", "172.16.2.116");

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
    assert_and_click("connection_user_password");
    type_very_safely($rdppass);
    assert_and_click("connection_authenticate");
    wait_still_screen(3);
    send_key("ret");
    type_very_safely("$password\n");
    wait_still_screen(2);

    # When SELinux is on, the authentication dialog has appeared.
    # Wait for it a minute and deal it away.
    if (check_screen("auth_required_password", timeout => 60)) {
        type_very_safely("$password\n");
    }

    # Start the terminal
    type_very_safely("terminal\n");
    wait_still_screen(3);

    # Check that we are on the correct computer.
    # We can tell from the terminal prompt.
    assert_screen("desktop_connected");

    # Unlock the parallel connection
    mutex_unlock("kaermorhen_opened");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}
1;
# vim: set sw=4 et:
