use base "installedtest";
use strict;
use testapi;
use utils;

# This part tests that we can do line numbering,
# otherwise the rest of the Gnome things are not
# supported. However, we may add more in the future.

sub run {
    my $self = shift;

    # Switches off line numbering (numbered by default).
    assert_and_click("kwrite_lines_numbered", button => "right");
    wait_still_screen(1);
    assert_and_click "kwrite_display_line_numbers";
    assert_screen "kwrite_lines_numbered_off";
}


sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
