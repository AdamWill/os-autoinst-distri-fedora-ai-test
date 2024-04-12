use base "installedtest";
use strict;
use testapi;
use utils;

# This sets the KDE desktop background to plain black, to avoid
# needle match problems caused by transparency.

sub run {
    my $self = shift;
    solidify_wallpaper;
    # to try and avoid problems with kde grinding a lot on first
    # attempt to do a menu_launch_type, let's do a throwaway one
    # here before we snapshot
    wait_screen_change { send_key 'super'; };
    wait_still_screen 3;
    send_key "k";
    wait_still_screen 5;
    send_key "esc";
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}


1;

# vim: set sw=4 et:
