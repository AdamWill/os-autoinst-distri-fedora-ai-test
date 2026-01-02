use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Krfb starts.

sub run {
    my $self = shift;

    # Start the application
    menu_launch_type('krfb', timeout => 60, checkstart => 1);
    wait_still_screen(3);
    # close the "remote control requested" window if shown
    send_key "esc";
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
