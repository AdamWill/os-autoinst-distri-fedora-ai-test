use base "installedtest";
use strict;
use warnings;
use testapi;
use utils;
use disks;
use mwriter;

# Selects a Fedora edition in Media Writer by opening the dropdown,
# clicking the given edition, and asserting the selected state.
sub select_edition {
    my $edition = shift;
    assert_and_click("mwriter_dropdown_arrow");
    assert_and_click("mwriter_select_$edition");
    assert_screen("mwriter_selected_$edition");
}

# Selects a Fedora version in Media Writer by opening the version dropdown
# and clicking the specified version entry.
sub select_version {
    my $version = shift;
    assert_and_click("mwriter_dropdown_version");
    assert_and_click("mwriter_select_$version");
}

# Selects a target architecture in Media Writer by opening the architecture
# dropdown and clicking the specified architecture entry.
sub select_arch {
    my $arch = shift;
    assert_and_click("mwriter_dropdown_arch");
    assert_and_click("mwriter_select_$arch");
}

sub run {
    my $self = shift;
    my $currver = get_var("CURRREL", "43");
    my $mediagroup = get_var('MEDIA', 'official');
    my $edition = get_var('EDITION', 'workstation');
    my $password = get_var('USER_PASSWORD', 'weakpassword');

    # Start the application
    menu_launch_type("media-writer", checkstart => 1);

    # Check that "Download automatically" is selected and select it if it is not.
    assert_and_click('mwriter_download_automatic');

    # Click "Next".
    assert_and_click('mwriter_next_button');

    # Select media group.
    assert_and_click("mwriter_mediagroup_$mediagroup");

    # Select edition to download.
    select_edition($edition);

    # Click "Next".
    assert_and_click('mwriter_next_button');

    # Select the version.
    select_version($currver);

    # Select hardware architecture
    select_arch("x86_64");

    # Check that USB drive is present.
    assert_screen("mwriter_usb_present");

    # Click the write button.
    assert_and_click('mwriter_write_button');

    # Confirm writing to usb.
    assert_and_click('mwriter_confirm_button');
    wait_still_screen(5);

    # When auth dialog appears, deal with it.
    authenticate(password => $password, timeout => 15, stillscreen => 3);

    # Sometimes, downloading does not start immediately
    # and a Write button is shown. If that is the case,
    # try clicking on the button to start.
    if (check_screen("mwriter_ready_button_write", timeout => 15)) {
        click_lastmatch();
    }

    # Wait for the download to finish. Because downloads could take
    # longer, let's perform a check every 30 second accompanied by mouse
    # movements to prevent the SUT from going to sleep.
    my $count = 0;
    my $limit = 80;
    until (check_screen("mwriter_finish_button")) {
        last if ($count >= $limit);
        sleep(30);    # Wait some time before checking again.
        $count++;
        # Move the mouse to prevent going to sleep.
        mouse_set(100, 100);
        sleep(1);    # Wait before moving the mouse back
        mouse_set(300, 300);
    }

    # Click on Finish button.
    assert_and_click("mwriter_finish_button");

    # Check that the "restore" option is shown in the main menu.
    assert_screen("mwriter_restore_item");

    # Go to console, perform tests, and come back
    $self->root_console(tty => 3);
    # Do the checksum and compare tests
    check_written_content();
    desktop_vt();
    # Shutdown the application
    send_key("alt-f4");
}


sub test_flags {
    return {fatal => 1};
}

1;
