use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that LibreOffice Calc starts.

sub run {
    my $self = shift;
    my $subvariant = get_var("SUBVARIANT", "Workstation");

    if ($subvariant ne "Silverblue") {
        # Start the application
        start_with_launcher('apps_menu_lcalc');
        # Check for the First Use warning and dismiss it,
        # before you try to quit the application.
        if (check_screen("lcalc_warning_firsttime", timeout => 15)) {
            send_key("alt-f4");
        }
        # Check that is started
        assert_screen 'apps_run_lcalc';
        # Register application
        register_application("libreoffice-calc");
        # Close the application
        quit_with_shortcut();
    }
    else {
        diag("LibreOffice Calc is not installed, skipping the test.");
    }
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
