use base "installedtest";
use strict;
use testapi;
use utils;

# This test tests if Terminal starts.

sub run {
    my $self = shift;
    # open the application
    menu_launch_type "terminal";
    assert_screen "apps_run_terminal";

    # Register application
    register_application("gnome-terminal");

    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
