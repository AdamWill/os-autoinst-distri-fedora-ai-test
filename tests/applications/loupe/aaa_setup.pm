use base "installedtest";
use strict;
use testapi;
use utils;

# This script will download the test data for EoG, start the application,
# and set a milestone as a starting point for the other Loupe tests.

sub run {
    my $self = shift;
    # Switch to console
    $self->root_console(tty => 3);
    # Perform git test
    check_and_install_git();
    # Download the test data
    download_testdata();
    # Exit the terminal
    desktop_vt;

    # Set the update notification timestamp
    set_update_notification_timestamp();
    # Start the application
    menu_launch_type("loupe", checkstart => 1, maximize => 1);

    # Open the test file to create a starting point for the other EoG tests.
    send_key("ctrl-o");

    # Open the Pictures folder.
    assert_and_click("gnome_dirs_pictures", button => "left", timeout => 30);

    # Select the image.jpg file.
    assert_and_click("loupe_file_select_jpg", button => "left", timeout => 30);

    # Hit enter to open it.
    send_key("ret");

    # Check that the file has been successfully opened.
    assert_screen("loupe_image_default");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
