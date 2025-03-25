use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Kaddressbook starts.

sub run {
    my $self = shift;

    # Start the application
    menu_launch_type('kaddressbook', timeout => 60, checkstart => 1);
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
