use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Videos starts.

sub run {
    my $self = shift;
    my $subvariant = get_var("SUBVARIANT", "Workstation");
    my $version = get_var("VERSION");

    if ($subvariant ne "Silverblue") {
        # Start the application
        start_with_launcher('apps_menu_video');
        # Check that is started
        assert_screen 'apps_run_video';
        # Register application
        if ($version eq "Rawhide") {
            register_application("showtime");
        }
        else {
            register_application("totem");
        }
        # Close the application
        quit_with_shortcut();
    }
    else {
        diag("Videos not installed, skipping the test.");
    }
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
