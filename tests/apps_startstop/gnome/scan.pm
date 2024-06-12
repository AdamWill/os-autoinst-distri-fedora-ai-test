use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Simple Scan starts.

sub run {
    my $self = shift;
    my $subvariant = get_var("SUBVARIANT", "Workstation");

    if ($subvariant ne "Silverblue") {
        # Start the application
        start_with_launcher('apps_menu_scan');
        # Check that is started
        assert_screen 'apps_run_scan';
        # Register application
        register_application("simple-scan");
        # Close the application
        quit_with_shortcut();
    }
    else {
        diag("Scan is not installed, skipping the test.");
    }
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
