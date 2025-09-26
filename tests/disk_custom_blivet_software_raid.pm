use base "anacondatest";
use strict;
use testapi;
use anaconda;

sub run {
    my $self = shift;
    # Go to INSTALLATION DESTINATION and ensure two disks are selected.
    # Because PARTITIONING starts with 'custom_blivet', this will select blivet-gui.
    select_disks(disks => 2);
    assert_and_click "anaconda_spoke_done";

    if (get_var("UEFI")) {
        # if we're running on UEFI, we need esp
        custom_blivet_add_partition(raid1 => 1, size => 1024, mountpoint => '/boot/efi', filesystem => 'efi_filesystem');
    }
    elsif (get_var("OFW")) {
        custom_blivet_add_partition(size => 4, filesystem => 'ppc_prep_boot');
    }
    else {
        # from anaconda-37.12.1 onwards, GPT is default for BIOS
        # installs, so we need biosboot partitions on each disk
        custom_blivet_add_partition(size => 1, filesystem => 'biosboot');
        wait_still_screen 3;
        assert_and_click "anaconda_blivet_disk_2";
        wait_still_screen 3;
        custom_blivet_add_partition(size => 1, filesystem => 'biosboot');
        # go back to disk 1 as custom_blivet_add_partition kinda expects
        # us to be there
        wait_still_screen 3;
        assert_and_click "anaconda_blivet_disk_1";
        wait_still_screen 3;
        assert_and_click "anaconda_blivet_free_space";
    }
    custom_blivet_add_partition(raid1 => 1, size => 1024, mountpoint => '/boot');
    custom_blivet_add_partition(raid1 => 1, mountpoint => '/');

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
