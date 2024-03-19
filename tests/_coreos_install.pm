use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    assert_screen "user_console", 300;
    type_string "sudo su\n";
    assert_script_run "coreos-installer install /dev/vda --ignition-url https://www.happyassassin.net/temp/openqa.ign", 600;
    # the CoreOS installer does not write an efibootmgr entry, so to
    # ensure we boot from hard disk on next boot, wipe the entry for
    # the optical drive
    assert_script_run('efibootmgr -b $(efibootmgr | grep CD-ROM | head -1 | cut -f1 | sed -e "s,[^0-9],,g") -B') if (get_var("UEFI"));
    type_string "reboot\n";
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
