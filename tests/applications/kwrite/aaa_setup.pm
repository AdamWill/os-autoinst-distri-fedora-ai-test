use base "installedtest";
use strict;
use testapi;
use utils;

# This part of the suite prepares downloads the test data and sets up the environment.

sub run {
    my $self = shift;

    # Go to the root console to set up the test data and necessary stuff.
    $self->root_console(tty => 3);

    # Get the test data from the test data repository.
    check_and_install_git();
    download_testdata();
    # Return to Desktop
    desktop_vt();

    # Workaround the KDE double char problem
    kde_doublek_workaround();
    # Start the application
    menu_launch_type("kwrite");
    # Check that it started
    assert_screen("apps_run_kwrite");

    # Hit key-combo to open the file
    send_key("ctrl-o");
    wait_still_screen(2);

    # Select the Documents directory and press Enter.
    assert_and_click("kwrite_select_documents");
    wait_still_screen(1);
    send_key("ret");

    # Choose the file
    assert_and_click("kwrite_txt_file");

    # Open it
    send_key("ret");
    wait_still_screen(3);

    # Make the application fullscreen
    assert_and_click("kde_window_maximize");
    wait_still_screen(3);

    # Check that the document has been opened
    assert_screen("kwrite_text_file_opened");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
