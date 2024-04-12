use base "installedtest";
use strict;
use testapi;
use utils;

# This test will test the Tour application.

sub run {
    my $self = shift;

    # Start the Application
    menu_launch_type("tour");

    assert_screen("tour_start");
    send_key("right");

    assert_screen("tour_overview");
    send_key("right");

    assert_screen("tour_search");
    send_key("right");

    assert_screen("tour_workspaces");
    send_key("right");

    assert_screen("tour_updown");
    send_key("right");

    assert_screen("tour_leftright");
    send_key("right");

    assert_screen("tour_done");
}

sub test_flags {
    # If this test fails, there is no need to continue.
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
