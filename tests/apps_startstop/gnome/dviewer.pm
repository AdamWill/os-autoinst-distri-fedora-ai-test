use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Document Viewer starts.
# Before Workstation Rawhide (43), that application was represented
# by Evince, now it is being replaced with Papers.

sub run {
    my $self = shift;
    # Start the application
    start_with_launcher('apps_menu_papers', 'apps_menu_utilities');
    # Check that is has started
    assert_screen('apps_run_papers');
    # Register the application into the list
    register_application('papers');
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
