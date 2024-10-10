use base "installedtest";
use strict;
use testapi;
use utils;

# This part of the suite tests if the volume levels
# are reflected in the volume bar in the control menu.
#

sub check_volume {
    my $level = shift;
    # Check that the volume indicator changes
    assert_screen("panel_volume_indicator_$level");
    # Open the control menu and check the volume bar
    # shows the status of the volume level.
    assert_and_click("panel_controls");
    assert_screen("panel_volume_bar_$level");
    # Close the control window
    send_key("esc");
    wait_still_screen(2, similarity_level => 38);
}

sub run {
    my $self = shift;
    # Open the terminal to enable us to set the
    # volume level.
    desktop_launch_terminal;
    assert_screen("apps_run_terminal");
    # Set the volume to 0%
    type_safely('amixer -D pipewire sset Master 0%');
    send_key('ret');
    # Check that it worked
    check_volume("zero");
    # Set the volume to 50%
    type_safely('amixer -D pipewire sset Master 50%');
    send_key('ret');
    # Check that it worked
    check_volume("fifty");
    # Set the volume to 100%
    type_safely('amixer -D pipewire sset Master 100%');
    send_key('ret');
    # Check that it worked
    check_volume("hundred");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
