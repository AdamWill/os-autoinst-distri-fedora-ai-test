use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Help Center starts.

sub run {
    my $self = shift;

    # Start the application
    menu_launch_type('help', checkstart => 1, timeout => 1);
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
