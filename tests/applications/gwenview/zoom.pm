use base "installedtest";
use strict;
use testapi;
use utils;

# This part tests if the application can change the zoom for the displayed picture.

sub run {
    my $self = shift;
    sleep 2;

    assert_screen("gwen_image_default");
    # Let us increase the image using the plus key
    mouse_set("500", "350");
    # Normally the picture is set to fit the screen,
    # use the F key to not fit it in.
    send_key("f");
    assert_screen("gwen_image_unfitted");
    # make it very huge
    assert_and_click("gwen_zoom_ratio");
    send_key("ctrl-a");
    type_very_safely("400%");
    wait_still_screen(2);
    assert_screen("gwen_image_zoomed_in");
    # return to normal
    send_key("tab");
    sleep(1);
    send_key("f");
    assert_screen("gwen_image_default");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
