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
    check_software_start();

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
