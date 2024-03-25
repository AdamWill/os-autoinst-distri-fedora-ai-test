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
    assert_and_click("kwrite_line_word");
    send_key("ctrl-shift-n");
    assert_and_click("kwrite_button_new_file");
    assert_screen "kwrite_new_document_opened";

    # Now let us produce some text
    type_very_safely "# My shopping list.\n\n";
    type_very_safely "* **Milk**\n* *Apples*\n* `Bananas`\n* Bread\n* Butter\n* Cheese\n\n";
    type_very_safely "Happy shopping.";

    # Switch on Markdown Highlighting.
    assert_and_click("kwrite_settings_normal");
    type_very_safely("markdown");
    assert_and_click("kwrite_settings_markdown");
    assert_screen("kwrite_markdown_selected", "down", 50);
    assert_screen "kwrite_code_highlighted";

    # Save the newly created file.
    send_key("ctrl-s");
    wait_still_screen(3);
    # select the entire prefilled name (including extension) to overwrite it
    send_key("ctrl-a");
    wait_still_screen(3);
    type_very_safely "list.md";
    send_key("ret");
    assert_screen("kwrite_file_saved");
    # Check that the file has been created
    $self->root_console(tty => 3);
    assert_script_run("ls /home/test/Documents/list.md");
    desktop_vt();
}


sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
