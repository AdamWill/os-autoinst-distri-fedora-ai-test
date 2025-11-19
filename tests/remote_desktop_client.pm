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
    connections_connect($ip, $rdpuser, $rdppass);
    # we should arrive at the login screen, so login
    assert_screen("login_screen");
    wait_still_screen 3;
    send_key_until_needlematch("graphical_login_input", "ret", 3, 5);
    type_very_safely("$password\n");
    assert_screen(["auth_required_password", "apps_menu_button_active"]);

    # When SELinux is on, the authentication dialog has appeared.
    # Wait for it a minute and deal it away.
    if (match_has_tag("auth_required_password")) {
        type_very_safely("$password\n");
        assert_screen("apps_menu_button_active");
    }

    # Start the terminal
    wait_still_screen(3);
    type_very_safely("terminal\n");

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
