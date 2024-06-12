use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that LibreOffice Impress starts.

sub run {
    my $self = shift;
    my $subvariant = get_var("SUBVARIANT", "Workstation");

    if ($subvariant ne "Silverblue") {
        # Start the application
        start_with_launcher('apps_menu_limpress');
        # Check that is started
        assert_and_click 'apps_run_limpress_start';
        assert_screen 'apps_run_limpress';
        # Register application
        register_application("libreoffice-impress");
        # Close the application
        quit_with_shortcut();
    }
    else {
        diag("LibreOffice Impress is not installed, skipping the test.");
    }
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
