use base "installedtest";
use strict;
use testapi;
use utils;

# This part of the suite tests that Evince is able to display content in a two-page mode.

sub run {
    my $self = shift;

    # Enter the menu
    assert_and_click("gnome_stack_menu", button => "left", timeout => 30);

    # Select the Dual mode
    assert_and_click("papers_menu_dual", button => "left", timeout => 30);

    # Check that the content is displayed in dual mode.
    assert_screen("papers_dual_mode", timeout => 30);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
