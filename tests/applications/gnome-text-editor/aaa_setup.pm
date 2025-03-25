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
    # Remove gedit on upgraded systems so we don't launch it by accident
    script_run("dnf -y remove gedit") if (get_var("IMAGETYPE") eq "upgrade");
    # Return to Desktop
    desktop_vt();

    # Set the update notification timestamp
    set_update_notification_timestamp();
    # Start the application
    menu_launch_type("text_editor", checkstart => 1, maximize => 1);

    # Open the test file
    send_key("ctrl-o");
    wait_still_screen(2);

    # Open the documents location
    assert_and_click("gnome_open_location_documents");

    # Choose the file
    assert_and_click("gte_txt_file");

    # Open it
    send_key("ret");
    wait_still_screen(3);

    # Check that the document has been opened
    assert_screen("gte_text_file_opened");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
