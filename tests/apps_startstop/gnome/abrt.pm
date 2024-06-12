use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that ABRT starts.

sub run {
    my $self = shift;
    my $subvariant = get_var("SUBVARIANT", "Workstation");

    if ($subvariant ne "Silverblue") {
        # Start the application
        start_with_launcher('apps_menu_abrt', 'apps_menu_utilities');
        # Check that it is started
        assert_screen 'apps_run_abrt';
        # Register application
        register_application('gnome-abrt');
        # Close the application
        quit_with_shortcut();
    }
    else {
        diag("Abrt is not installed, skipping the test.");
    }
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
