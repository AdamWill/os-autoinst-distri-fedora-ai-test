use base "installedtest";
use strict;
use testapi;
use utils;

# This script will download the test data for Gwenview, start the application,
# and set a milestone as a starting point for the other Gwenview tests.

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

    kde_doublek_workaround(key => 'g');
    # Start the application
    menu_launch_type("gwenview");
    # Check that is started
    assert_screen 'imageviewer_runs';

    # Fullsize the application window.
    send_key("super-pgup");

    # Open the test file to create a starting point for the other tests.
    send_key("ctrl-o");

    # Open the Pictures folder.
    assert_and_dclick("gwen_pictures_directory", button => "left", timeout => 30);

    # Select the image.jpg file.
    assert_and_click("gwen_file_select_jpg", button => "left", timeout => 30);

    # Hit enter to open it.
    send_key("ret");

    # Check that the file has been successfully opened.
    assert_screen("gwen_image_default");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
