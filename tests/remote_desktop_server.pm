use base "installedtest";
use strict;
use testapi;
use utils;
use lockapi;
use mmapi;

sub run {
    my $self = shift;
    my $user = get_var("USER_LOGIN", "test");
    my $password = get_var("USER_PASSWORD", "weakpassword");
    my $rdpuser = "geralt";
    my $rdppass = "ciriofcintra";

    $self->root_console(tty => 3);
    # Make necessary settings for the RDP server.
    # Set SElinux to permissive to workaround a Fedora issue
    assert_script_run("setenforce 0");
    # Check that SElinux is in permissive mode
    validate_script_output("getenforce", sub { m/Permissive/ });

    # In Workstation, the RDP port should be opened per se,
    # but let's open it explicitely, to make sure it is open.
    assert_script_run("firewall-cmd --add-port=3389/tcp");

    # Change to Desktop
    desktop_vt();

    # Open Settings and navigate to Remote Login
    menu_launch_type("Settings");
    send_key("ctrl-f");
    sleep(2);
    type_very_safely("system");
    assert_and_click("settings_system");
    assert_and_click("settings_remote_desktop");
    assert_and_click("settings_remote_login");
    assert_and_click("gnome_button_unlock");
    if (check_screen("auth_required_password", timeout => 60)) {
        type_very_safely("$password\n");
    }
    else {
        die("Authentication dialogue is not visible but was expected.");
    }

    # Set up remote login in Gnome Settings.
    assert_and_click("settings_switch_remote");
    wait_still_screen(3);
    assert_and_click("settings_remote_username");
    type_very_safely($rdpuser);
    assert_and_click("settings_remote_password");
    type_very_safely($rdppass);
    assert_and_click("gnome_reveil_password");
    wait_still_screen(3);
    assert_and_click("settings_button_back");
    send_key("alt-f4");

    # RDP does not allow connections when the user is still logged in
    # locally, so let's reboot the machine to start from anew.
    assert_and_click("system_menu_button");
    assert_and_click("leave_button");
    assert_and_click("reboot_entry");
    assert_and_click("gnome_reboot_confirm");
    assert_screen("graphical_login", 240);


    # Check that the service is running. If the service was not running,
    # let's record a soft failure and start the RDP service.
    $self->root_console(tty => 3);
    if (script_run("systemctl status gnome-remote-desktop --no-pager")) {
        record_soft_failure("The Gnome Remote Desktop service is not running.");
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
