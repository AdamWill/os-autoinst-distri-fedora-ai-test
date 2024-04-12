use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Software starts.

sub run {
    my $self = shift;

    # Start the application
    start_with_launcher('apps_menu_software');


    # check if third party dialog appears, if so, click it away
    if (check_screen 'gnome_software_ignore', 10) {
        wait_still_screen 3;
        # match again as the dialog may have moved a bit
        assert_and_click 'gnome_software_ignore';
    }
    assert_screen 'desktop_package_tool_update';
    # Register application
    register_application("gnome-software");
    # Close the application
    quit_with_shortcut();

}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
