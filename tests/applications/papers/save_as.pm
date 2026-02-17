use base "installedtest";
use strict;
use testapi;
use utils;

# This part of the suite tests tests that Evince can Save the document As another document.

sub run {
    my $self = shift;

    # Open the menu.
    assert_and_click("gnome_stack_menu", button => "left", timeout => 30);

    # Select Save As
    assert_and_click("papers_menu_saveas", button => "left", timeout => 30);
    wait_still_screen(2);

    # we should be in the Documents dir, but may not be due to
    # https://bugzilla.redhat.com/show_bug.cgi?id=2435752
    unless (check_screen("nautilus_documents_active", 30)) {
        record_soft_failure("Opened in wrong directory - https://bugzilla.redhat.com/show_bug.cgi?id=2435752");
        assert_and_click("papers_documents");
        assert_and_click("papers_select_file");
    }

    # Type a new name.
    type_very_safely("alternative");

    # Click on the Save button
    assert_and_click("gnome_button_save", button => "left", timeout => 30);

    # Now the document is saved under a different name. We will switch to the
    # terminal console to check that it has been created.
    $self->root_console(tty => 3);
    my $filename = "alternative.pdf";
    if (script_run("ls /home/test/Documents/${filename}")) {
        $filename = "alternativeevince.pdf";
        assert_script_run("ls /home/test/Documents/${filename}");
        record_soft_failure("File name was not pre-selected in Save As dialog: https://gitlab.gnome.org/GNOME/xdg-desktop-portal-gnome/-/issues/75");
    }

    # Now, check that the new file does not differ from the original one.
    assert_script_run("diff /home/test/Documents/evince.pdf /home/test/Documents/${filename}");
}

sub test_flags {
    return {always_rollback => 1};
}

1;
