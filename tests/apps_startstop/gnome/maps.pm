use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Maps starts.

sub run {
    my $self = shift;

    # Start the application
    start_with_launcher('apps_menu_maps');
    # Check that is started
    # give access rights if asked
    if (check_screen('grant_access', 5)) {
        assert_and_click 'grant_access';
    }
    assert_screen 'apps_run_maps';
    # Register application
    register_application("gnome-maps");
    # Close the application
    quit_with_shortcut();

}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
