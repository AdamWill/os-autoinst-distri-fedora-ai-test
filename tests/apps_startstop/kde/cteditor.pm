use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Control Theme Editor starts.

sub run {
    my $self = shift;
    menu_launch_type 'contactthemeeditor';
    # Check that it is started
    assert_screen 'apps_run_cteditor';
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
