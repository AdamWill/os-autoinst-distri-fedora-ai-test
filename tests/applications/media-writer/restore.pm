use base "installedtest";
use strict;
use warnings;
use testapi;
use utils;
use disks;
use mwriter;

sub run {
    my $self = shift;
    my $password = get_var("USER_PASSWORD", "weakpassword");
    # Start the application
    menu_launch_type("media-writer", checkstart => 1);

    # Select the option to restore the drive.
    assert_and_click('mwriter_restore_item');

    # Click "Next".
    assert_and_click('mwriter_next_button');

    # Click on Renew button
    assert_and_click("mwriter_restore_button");

    # Confirm renovation.
    wait_still_screen(5);
    authenticate($password, timeout => 15, stillscreen => 3);

    # Wait up to 300 sec and wait for confirmation.
    # As this operation should be quicker, we do not have to
    # do any complicated waits.
    assert_and_click("mwriter_disk_restored", timeout => 300);
    assert_and_click("mwriter_finish_button");

    # Check that the "restore" option is not shown in the main menu.
    if (check_screen("mwriter_restore_item")) {
        record_soft_failure("The restore option is still shown, but it should not be.");
    }

    # Go to console, perform tests, and come back
    $self->root_console(tty => 3);
    assert_script_run("mount /dev/sda1 /mnt/usbdisk");
    # The usb should be mountable but empty.
    assert_script_run('test -z "$(ls -A /mnt/usbdisk)"');
    desktop_vt();
    # Stop the application
    send_key("alt-f4");
}


sub test_flags {
    return {fatal => 1};
}

1;
