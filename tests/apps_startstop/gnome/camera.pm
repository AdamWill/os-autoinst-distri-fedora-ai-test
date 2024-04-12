use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Camera (snapshot) starts.

sub run {
    my $self = shift;
    # FIXME after F39 is stable, drop the old 'cheese' needles
    # and always expect the access dialog

    # Start the application
    start_with_launcher('apps_menu_camera');
    # Check that is started or we see the camera access dialog
    assert_screen ['apps_run_camera', 'grant_access'];
    if (match_has_tag 'grant_access') {
        click_lastmatch;
        assert_screen 'apps_run_camera';
    }
    # Register application
    register_application("gnome-snapshot");
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
