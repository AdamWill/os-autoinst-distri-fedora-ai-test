use base "installedtest";
use strict;
use testapi;
use utils;

# This part of the suite tests an annotation can be added to the displayed content.

sub run {
    my $self = shift;

    # Select location to add annotation.
    assert_and_click("papers_select_annotation_place", button => "right", timeout => 30);

    # Add the annotation.
    assert_and_click("papers_add_annotation");
    wait_still_screen(2);

    # Enter some text to the annotation.
    type_very_safely("This is a very important annotation.");

    # Check that the annotation window has appeared with that text.
    assert_screen("papers_annotation_added");

    # Close the annotation.
    assert_and_click("papers_close_annotation");

    # Check that the annotation is still placed in the document.
    assert_screen("papers_annotation_placed");

    # Open the annotation's context menu.
    assert_and_click("papers_annotation_placed", button => "right");

    # Open the Properties
    assert_and_click("papers_annotation_properties");

    # Change the color
    assert_and_click("papers_annotation_color");
    assert_and_click("papers_select_color");
    assert_and_click("gnome_button_select");
    assert_and_dclick("papers_opacity_hundred");
    type_very_safely("70");
    if (check_screen("gnome_button_apply", 10)) {
        click_lastmatch;
    }
    else {
        send_key('esc');
    }
    assert_screen("papers_annotation_placed");    # Different opacity

    # Remove the annotation.
    assert_and_click("papers_annotation_placed", button => "right");
    assert_and_click("papers_remove_annotation");

    # Check that the annotation has been removed.
    assert_screen("papers_annotation_removed");
}

sub test_flags {
    # Rollback to the starting point.
    return {always_rollback => 1};
}

1;
