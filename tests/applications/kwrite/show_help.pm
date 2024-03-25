use base "installedtest";
use strict;
use testapi;
use utils;

# This part tests that Help can be shown.

sub run {
    my $self = shift;
    sleep(5);
    # Click into the window to get focus
    assert_and_click("kwrite_line_title");
    # Open Help.
    send_key("f1");
    assert_screen "kwrite_help_shown";

    ## Navigate through several screens
    assert_and_click("kwrite_help_title");
    # Use down arrow to navigate through the screen
    # to arrive at something clickable.
    send_key_until_needlematch("kwrite_help_link_introduction", "down", 7);
    click_lastmatch;
    assert_screen "kwrite_help_introduction";
    send_key_until_needlematch("kwrite_help_next", "down", 7);
    click_lastmatch;
    assert_screen("kwrite_help_cmdoptions");
    assert_and_click("kwrite_help_next");
    assert_screen("kwrite_help_credits");
}


sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
