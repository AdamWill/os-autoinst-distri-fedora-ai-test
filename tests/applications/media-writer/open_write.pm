use base "installedtest";
use strict;
use warnings;
use testapi;
use utils;
use disks;
use mwriter;

sub run {
    my $self = shift;
    # Start the application
    menu_launch_type("media-writer", checkstart => 1);

    # Select the option to pick an ISO file.
    assert_and_click('mwriter_choose_isofile');

    # Click "Next".
    assert_and_click('mwriter_next_button');

    # Click on Choose button
    assert_and_click("mwriter_choose_button");

    # Navigate to Downloaded files.
    assert_and_click("nautilus_directory_downloads");

    # Select the ISO you want to reuse.
    assert_and_click('mwriter_select_isofile');

    # Click on Select button
    assert_and_click('gnome_button_select');

    # Check that USB drive is present.
    assert_screen("mwriter_usb_present");

    # Click the write button.
    assert_and_click('mwriter_write_button');

    # Confirm writing to usb.
    assert_and_click('mwriter_confirm_button');
    wait_still_screen(5);
    authenticate();

    # Wait up to 300 sec and try to click on Finish button.
    assert_and_click("mwriter_finish_button", timeout => 300);

    # Check that the "restore" option is shown in the main menu.
    assert_screen("mwriter_restore_item");

    # Go to console, perform tests, and come back
    $self->root_console(tty => 3);
    # Try creating the mountpoint (just in case), do not mind
    # if it fails for its existence.
    script_run("mkdir -p /mnt/usbdisk");
    confirm_disk_modification("write");
    desktop_vt();
    # Stop the application
    send_key("alt-f4");
}


sub test_flags {
    return {fatal => 1};
}

1;
