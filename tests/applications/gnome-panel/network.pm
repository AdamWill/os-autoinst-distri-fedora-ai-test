use base "installedtest";
use strict;
use testapi;
use utils;

# This part of the suite Tests that the panel
# can be used to switch network off and on.

sub switch_network {
    my $type = shift;
    # Click on the controls.
    assert_and_click("panel_controls");
    # Click on Network button to toggle network
    assert_and_click("panel_ctrl_networks");
    wait_still_screen(2);
    # Get rid of the window to be able to make tests
    send_key("esc");
}

sub run {
    my $self = shift;
    # Toggle network
    switch_network();

    # Switch to console
    $self->root_console(tty => 3);
    # If there is no network the script fails which is exactly
    # what we need.
    assert_script_run("! ping -c 10 8.8.8.8");
    # Let's switch back to desktop. Normally, we would use the
    # desktop_vt subroutine, but since we do not have networking
    # it does not work reliably. Ergo, we will use the old known
    # ctrl-alt-f2
    select_console "tty2-console";
    # Sometimes, we can see an authentication dialogue which
    # prevents the test from continuing. Authenticate,
    # if that is the case.
    my $pass = get_var("USER_PASSWORD", "weakpassword");
    if (check_screen("auth_required", timeout => 30)) {
        type_very_safely("$pass\n");
    }
    sleep(3);

    # Toggle network
    switch_network();
    # Switch to console
    $self->root_console(tty => 3);
    # If there is no network the script fails which is exactly
    # what we need.
    assert_script_run("ping -c 10 8.8.8.8");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:

