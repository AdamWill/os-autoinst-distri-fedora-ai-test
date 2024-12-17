use base "installedtest";
use strict;
use testapi;
use utils;

# This part tests that we can create a new file that
# opens in a new panel, that we can add text, display
# text statistics and highlight code and save the file.

sub run {
    my $self = shift;

    # First we will use key combo to open the new document window.
    sleep 5;
    # Click into the text to regain focus.
    assert_and_click("gte_line_word");
    send_key("ctrl-t");
    assert_screen "gte_new_document_opened";

    # Now let us produce some text
    type_very_safely "# My shopping list.\n\n";
    type_very_safely "* **Milk**\n* *Apples*\n* `Bananas`\n* Bread\n* Butter\n* Cheese\n\n";
    type_very_safely "Happy shopping.";

    # Switch on Markdown Highlighting.
    assert_and_click("gte_settings_button");
    assert_and_click "gte_select_highlighting";
    wait_still_screen(2);
    type_very_safely "markdown";
    send_key "ret";
    assert_and_click("gte_window_dismiss");
    assert_screen "gte_code_highlighted";

    # Save the newly created file.
    send_key("ctrl-s");
    wait_still_screen(3);

    if (check_screen "nautilus_save_filename") {
        # if we hit the nautilus save-as screen, we have to select
        # the right folder...
        assert_and_click "nautilus_directory_documents";
        # then click to edit the filename
        assert_and_click "nautilus_save_filename";
    }
    # select the entire prefilled name (including extension) to overwrite it
    send_key("ctrl-a");
    wait_still_screen(3);
    type_very_safely "list.md";
    assert_and_click("gnome_button_save");
    assert_screen("gte_file_saved");
    # Check that the file has been created
    $self->root_console(tty => 3);
    # it might be in either of these places depending on version / release
    assert_script_run("ls /home/test/Documents/list.md || ls /home/test/list.md");
    desktop_vt();
}


sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
