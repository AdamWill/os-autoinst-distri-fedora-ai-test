use base "installedtest";
use strict;
use testapi;
use utils;

# This part of the suite tests that Papers can change the zoom of the document.

sub repeat_click {
    my ($tag, $times) = @_;
    for (1 .. $times) {
        assert_and_click($tag);
    }
}


sub run {
    my $self = shift;

    # Check the initial zoom
    assert_screen("papers_zoom_initial");

    # Increase the zoom
    repeat_click("papers_zoom_add", 3);
    assert_screen("papers_zoom_increased");

    # Return to the original size
    assert_and_click("papers_zoom_fit");
    assert_screen("papers_zoom_initial");

    # Decrease the zoom.
    repeat_click("papers_zoom_subtract", 3);
    assert_screen("papers_zoom_decreased");

    # Return to the original size
    assert_and_click("papers_zoom_fit");
    assert_screen("papers_zoom_initial");
}

sub test_flags {
    return {always_rollback => 1};
}

1;
