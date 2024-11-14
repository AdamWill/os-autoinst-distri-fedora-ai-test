use base "installedtest";
use strict;
use testapi;
use utils;

# This part tests if the application can navigate through the current folder.

sub run {
    my $self = shift;

    # wait to settle from snapshot
    wait_still_screen 3;
    # Go to next picture.
    send_key("right");
    assert_screen("gwen_image_next", timeout => 90);
    # Go to previous picture
    send_key("left");
    assert_and_click("gwen_image_default", timeout => 90);
    # Show the browse menu
    assert_and_click("gwen_show_browse");
    # Check it
    assert_screen("gwen_browse_shown");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
