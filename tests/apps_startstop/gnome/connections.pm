use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Connections start.

sub run {
    my $self = shift;

    # Start the application
    start_with_launcher('apps_menu_connections', 'apps_menu_utilities');
    # The Connections will show a pop up window. Dismiss it.
    assert_screen('apps_connections_popup');
    assert_and_click('apps_connections_nothanks');
    # Check that the app is still running
    assert_screen('apps_run_connections');
    # Register application
    register_application('connections');
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
