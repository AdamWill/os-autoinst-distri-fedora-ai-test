use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Fedora Media Writer starts
# on Silverblue.

sub run {
    my $self = shift;
    my $subvariant = get_var("SUBVARIANT");
    if ($subvariant eq "Silverblue") {
        # Start the application
        start_with_launcher('apps_menu_fmw');
        # Check that is started
        assert_screen 'apps_run_fmw';
        # Register application
        register_application('fedora-media-writer');
        # Close the application
        quit_with_shortcut();
    }
    else {
        diag("Fedora Media Writer is not installed on Workstation by default. Skipping test.");
    }
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
