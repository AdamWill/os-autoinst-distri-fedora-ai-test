use base "installedtest";
use strict;
use testapi;
use utils;

# Show and unshow hidden files.

sub toggle_hidden {
    # Toggle hidden files using keyboard short cut or menu.
    my $type = shift;
    if ($type eq "menu") {
        my $relnum = get_release_number;
        if ($relnum > 40) {
            assert_and_click("nautilus_view_menu");
        }
        else {
            assert_and_click("gnome_burger_menu");
        }
        wait_still_screen(2);
        assert_and_click("nautilus_toggle_hidden_files", timeout => '30', button => 'left', mousehide => '1');
        sleep(10);
    }
    else {
        send_key("ctrl-h");
        sleep(10);
    }
}

sub run {
    my $self = shift;

    #  Enter the Documents directory.
    assert_and_click("nautilus_directory_documents", timeout => '30', button => 'left', mousehide => '1');

    # Check that we are in the Documents directory.
    assert_screen("nautilus_documents_active", timeout => '30', no_wait => '0');

    # Check if the hidden files are set to shown. If so, let's remember this status quo for further testing.
    my $hidden_a = 0;
    my $hidden_b = 0;

    # Set the a variable to 1, if the hidden files are shown.
    if (check_screen("nautilus_hidden_file_shown")) {
        $hidden_a = 1;
    }

    # Now toggle the status of the invisible files and check that it is changed now
    # using the keyboard shortcut.
    toggle_hidden("key");

    # Now let us check again, if the invisible file is seen.
    if (check_screen("nautilus_hidden_file_shown")) {
        $hidden_b = 1;
    }

    # Compare the results. They should differ from each other.
    if ($hidden_a == $hidden_b) {
        die("The ctrl-h keyboard shortcut should have changed the status of invisible files, but the status has not been changed which indicates that the shortcut might not have worked correctly.");
    }

    # Toggle again
    toggle_hidden("menu");

    # Check the current status of the invisible files.
    if (check_screen("nautilus_hidden_file_shown")) {
        $hidden_b = 1;
    }
    else {
        $hidden_b = 0;
    }

    # Compare the results. They should be the same if everything up til now has worked correctly.
    if ($hidden_a != $hidden_b) {
        die("The menu item 'Show hidden files' should have changed the status of the invisible files, but the status has not changed which indicates that the menu item might not have worked correctly.");
    }
}

sub test_flags {
    # Rollback to the previous state to make space for other parts.
    return {always_rollback => 1};
}

1;


