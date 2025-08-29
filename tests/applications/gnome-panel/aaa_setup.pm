use base "installedtest";
use strict;
use testapi;
use utils;

# This part of the suite prepares the environment.

sub run {
    my $self = shift;
    # Set the update notification timestamp
    # note: this will mean it's waaay in the future compared to the
    # fake time we set below and use for the rest of the test, but
    # that should do the job fine
    set_update_notification_timestamp();

    # Go to the root console to set up the test data and necessary stuff.
    $self->root_console(tty => 3);

    # As we want to deal with certain elements during testing,
    # we need to set the time and zones, otherwise we would need many needles.
    # Disable the automatic time and zone settings
    script_run("timedatectl set-ntp False");
    # Set the time zone
    script_run("timedatectl set-timezone Europe/Prague");
    # Set the time
    script_run("date 030518302023");
    # Make serial writable
    script_run("chmod 666 /dev/ttyS0");
    # Return to Desktop
    desktop_vt();
    # Check that the upper panel shows correct date and time.
    assert_screen("panel_datetime");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
