use base "installedtest";
use strict;
use testapi;
use utils;

# We will start two applications and save the progress.

sub run {
    my $self = shift;
    # Let us wait here for a couple of seconds to give the VM time to settle.
    # Starting right over might result in erroneous behavior.
    sleep(5);
    # Set the update notification timestamp
    set_update_notification_timestamp();
    # Start Firefox
    menu_launch_type("nautilus");
    assert_screen "apps_run_files", 45;
    # let it settle a bit
    wait_still_screen(stilltime => 5, similarity_level => 45);
    send_key("super-up");
    assert_screen("navigation_files_fullscreen");

    # Start Gnome Text Editor
    menu_launch_type("text-editor");
    assert_screen("apps_run_editor");
    wait_still_screen(2);
    send_key("super-up");
    assert_screen("navigation_editor_fullscreen");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:



