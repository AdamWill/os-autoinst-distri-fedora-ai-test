use base "anacondatest";
use strict;
use utils;
use testapi;
use anaconda;

sub run {
    my $self = shift;
    # Go to INSTALLATION DESTINATION and ensure the disk is selected.
    # Because PARTITIONING starts with 'custom_blivet', this will select blivet-gui.
    select_disks();
    assert_and_click "anaconda_spoke_done";

    if (get_var("UEFI")) {
        # if we're running on UEFI, let us reformat the UEFI first
        # Select the UEFI partition if it is not selected by default;
        # if it is, clicking it is harmless
        assert_and_click "anaconda_blivet_part_efi";
        wait_still_screen 5;

        # Go to the partition settings
        assert_and_click "anaconda_blivet_part_edit";
        # Select the Format option
        assert_and_click "anaconda_blivet_part_format";
        assert_and_click "anaconda_blivet_part_fs_select";
        unless (check_screen "anaconda_blivet_part_fs_efi_filesystem", 5) {
            record_soft_failure "https://bugzilla.redhat.com/show_bug.cgi?id=2324231";
            for (1 .. 15) {
                send_key "up";
            }
        }
        assert_and_click "anaconda_blivet_part_fs_efi_filesystem";
        # Select the mountpoint field

        send_key_until_needlematch("anaconda_blivet_mountpoint_selected", "tab", 3, 5);
        # Fill in the mountpoint
        type_very_safely "/boot/efi";
        # Confirm the settings
        assert_and_click "anaconda_blivet_part_format_button";
    }

    # Reformat the /boot partition
    wait_still_screen 2;
    assert_and_click "anaconda_blivet_part_boot";
    assert_and_click "anaconda_blivet_part_boot" unless (check_screen "anaconda_blivet_part_boot_selected", 5);
    wait_still_screen 5;

    # Go to the partition settings
    assert_and_click "anaconda_blivet_part_edit";
    # Select the Format option
    assert_and_click "anaconda_blivet_part_format";
    assert_and_click "anaconda_blivet_part_fs_select";
    assert_and_click "anaconda_blivet_part_fs_ext4";
    # Select the mountpoint field
    send_key_until_needlematch("anaconda_blivet_mountpoint_selected", "tab", 3, 5);
    # Fill in the mountpoint
    type_very_safely "/boot";
    # Confirm the settings
    assert_and_click "anaconda_blivet_part_format_button";

    # Select the BTRFS part
    assert_and_click "anaconda_blivet_volumes_icon";

    # Select the home partition
    assert_and_click "anaconda_blivet_part_home";
    # Go to the partition settings
    assert_and_click "anaconda_blivet_part_edit";
    # Select the Set mountpoint option
    assert_and_click "anaconda_blivet_part_setmountpoint";
    # Type the mountpoint
    type_very_safely "/home";
    # Confirm
    assert_and_click "anaconda_blivet_part_setmountpoint_button";
    # Wait some time for the pane to settle, without this,
    # the needle boolean check will fade too fast without actually
    # taking any effect.
    sleep 5;

    # While there are some root subvolumes (it seems that there can be more than one)
    # continue to delete them.
    while (check_screen "anaconda_blivet_part_root_exists", 2) {
        assert_and_click "anaconda_blivet_part_root_exists";
        wait_still_screen 2;
        assert_and_click "anaconda_blivet_part_delete";
        assert_and_click "anaconda_blivet_btn_ok";
        sleep 5;
    }

    # Add new root partition
    assert_and_click "anaconda_add";
    # Select the name textfield
    send_key_until_needlematch("anaconda_blivet_part_name_selected", "tab", 3, 5);
    # type the new name
    type_very_safely "newroot";
    # Go to next field
    send_key "tab";
    # Type the mountpoint
    type_very_safely "/";
    # Confirm settings
    assert_and_click "anaconda_blivet_btn_ok";

    # Confirm everything and close the hub
    assert_and_click "anaconda_spoke_done";
    assert_and_click "anaconda_part_accept_changes";

    # Anaconda hub
    assert_screen "anaconda_main_hub", 300;

}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
