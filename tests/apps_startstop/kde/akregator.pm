use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Akregator starts.

sub run {
    my $self = shift;
    # Start the application
    menu_launch_type('akregator', checkstart => 1, timeout => 60);
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
