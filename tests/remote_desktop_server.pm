use base "installedtest";
use strict;
use testapi;
use utils;
use lockapi;
use mmapi;

sub run {
    my $self = shift;
    my $password = get_var("USER_PASSWORD", "weakpassword");
    my $rdpuser = get_var("RDP_USER", "geralt");
    my $rdppass = get_var("RDP_PASS", "ciriofcintra");

    $self->root_console(tty => 3);
    # Make necessary settings for the RDP server.

    # In Workstation, all ports should be allowed in Firewall.
    # If this is not true:
    if (script_run('firewall-cmd --list-all | grep "1025-65535/tcp"') != 0) {
        # If the above failed, let's try that at least the RDP port is opened.
        if (script_run('firewall-cmd --list-ports | grep 3389/tcp') != 0) {
            # If the above failed, let's try that the service is added.
            if (script_run('firewall-cmd --list-services | grep rdp') != 0) {
                # If the above failed, let's open the port manually and softfail the test.
                assert_script_run("firewall-cmd --add-port=3389/tcp");
                record_soft_failure("The RDP port was not opened, we had to open it manually.");
            }
        }
    }

    # Change to Desktop
    desktop_vt();

    # Open Settings and navigate to Remote Login
    menu_launch_type("Settings");
    send_key("ctrl-f");
    wait_still_screen(2);
    type_very_safely("system");
    assert_and_click("settings_system");
    assert_and_click("settings_remote_desktop");
    assert_and_click("settings_remote_login");
    assert_and_click("gnome_button_unlock");
    assert_screen("auth_required_password", timeout => 60);
    type_very_safely("$password\n");

    # Set up remote login in Gnome Settings.
    assert_and_click("settings_switch_remote");
    wait_still_screen(3);
    assert_and_click("settings_remote_username");
    type_very_safely($rdpuser);
    assert_and_click("settings_remote_password");
    type_very_safely($rdppass);
    assert_and_click("gnome_reveal_password");
    wait_still_screen(3);
    assert_and_click("settings_button_back");
    send_key("alt-f4");

    # RDP does not allow connections when the user is still logged in
    # locally, so let's reboot the machine to start from anew.
    reboot_system();


    # Check that the service is running. If the service was not running,
    # let's record a soft failure and start the RDP service.
    $self->root_console(tty => 3);
    if (script_run("systemctl is-active --quiet gnome-remote-desktop")) {
        record_soft_failure("The Gnome Remote Desktop service is not running, we had to start it manually.");
        assert_script_run("systemctl enable --now gnome-remote-desktop");
    }

    # Create mutex to synchronise with the children.
    mutex_create("kaermorhen_opened");
    wait_for_children();
}

sub test_flags {
    return {fatal => 1};
}
1;
# vim: set sw=4 et:
