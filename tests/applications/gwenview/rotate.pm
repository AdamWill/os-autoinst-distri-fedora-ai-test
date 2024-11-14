use base "installedtest";
use strict;
use testapi;
use utils;

# This part tests if the application can rotate the displayed picture.

sub run {
    my $self = shift;

    # Rotate left
    send_key("shift-ctrl-r");
    wait_still_screen(3);
    assert_screen("gwen_image_rotated_left");
    # Rotate right
    send_key("ctrl-r");
    wait_still_screen(3);
    assert_and_click("gwen_image_default");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
