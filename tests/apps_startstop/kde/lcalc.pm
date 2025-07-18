use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that LibreOffice Calc starts.

sub run {
    my $self = shift;
    # Start the application
    menu_launch_type 'libreoffice calc';
    # Check for the First Use warning and dismiss it,
    # before you try to quit the application.
    if (check_screen("lcalc_warning_firsttime", timeout => 15)) {
        send_key("alt-f4");
    }
    # Check that it is started
    assert_screen 'apps_run_lcalc', timeout => 60;
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
