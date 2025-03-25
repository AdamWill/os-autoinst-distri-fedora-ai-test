use base "installedtest";
use strict;
use testapi;
use utils;

# This script will start Fonts and save a milestone for the
# subsequent tests.

sub run {
    my $self = shift;
    # set the update notification timestamp
    set_update_notification_timestamp();

    # Start the application, unless already running.
    menu_launch_type("fonts", checkstart => 1, maximize => 1);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
