use base "installedtest";
use strict;
use testapi;
use utils;

# This will set up the environment for the Characters test.
# It will open the application and save a milestone.

sub run {
    my $self = shift;
    # Set the update notification timestamp
    set_update_notification_timestamp();

    # Start the application
    menu_launch_type("characters", checkstart => 1, maximize => 1);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
