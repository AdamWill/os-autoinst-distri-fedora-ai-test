use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Boxes starts.

sub run {
    my $self = shift;
    my $subvariant = get_var("SUBVARIANT", "Workstation");

    if ($subvariant ne "Silverblue") {
        # Start the application
        start_with_launcher('apps_menu_boxes');
        assert_screen 'apps_boxes_tutorial';
        send_key 'esc';
        unless (check_screen 'apps_run_boxes', 30) {
            record_soft_failure "Single esc didn't clear tutorial - #2005458?";
            send_key 'esc';
            assert_screen 'apps_run_boxes';
        }

        # Register application
        register_application("gnome-boxes");
        # Close the application
        quit_with_shortcut();
    }
    else {
        diag("Boxes is not installed, skipping the test.");
    }
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
