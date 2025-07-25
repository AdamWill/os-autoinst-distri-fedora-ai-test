use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Disk Usage starts.

sub run {
    my $self = shift;

    # Start the application
    start_with_launcher('apps_menu_diskusage', 'apps_menu_system');
    # Check that is started
    assert_screen 'apps_run_diskusage';
    # Register application
    register_application("baobab");
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
