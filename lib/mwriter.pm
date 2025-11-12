package mwriter;

use strict;

use base 'Exporter';
use Exporter;
use lockapi;
use testapi;
use utils;

our @EXPORT = qw(select_edition select_version select_arch confirm_disk_modification);


sub select_edition {
    my $edition = shift;
    assert_and_click("mwriter_dropdown_arrow");
    assert_and_click("mwriter_select_$edition");
    assert_screen("mwriter_selected_$edition");
}

sub select_version {
    my $version = shift;
    assert_and_click("mwriter_dropdown_version");
    assert_and_click("mwriter_select_$version");
}

sub select_arch {
    my $arch = shift;
    assert_and_click("mwriter_dropdown_arch");
    assert_and_click("mwriter_select_$arch");
}

sub confirm_disk_modification {
    my ($mod) = @_;

    my $disk = '/dev/sda';
    my $part1 = "${disk}1";
    my $part2 = "${disk}2";

    # Basic disk and partitioning sanity
    assert_script_run("lsblk | grep -w sda");
    assert_script_run("lsblk | grep -w sda1");
    assert_script_run("lsblk | grep -w sda2") if $mod eq 'write';

    # Mountpoints are created in the main code, here we only mount and unmount
    assert_script_run("mount ${part1} /mnt/usbdisk");

    if ($mod eq 'write') {
        # These structures must exist when we check for "write".
        my @must_exist = (
            '/mnt/usbdisk/boot/grub2/grub.cfg',
            '/mnt/usbdisk/EFI/BOOT',
            '/mnt/usbdisk/EFI/fedora',
            '/mnt/usbdisk/LiveOS/squashfs.img',
            '/mnt/usbdisk/mach_kernel',
            '/mnt/usbdisk/System/Library/CoreServices/SystemVersion.plist',
        );

        for my $path (@must_exist) {
            # test -e → 0 = OK (exists) or die
            assert_script_run("test -e $path && echo OK");
        }
    }
    elsif ($mod eq 'restore') {
        # These structures must not exist when "restore"
        my @must_be_gone = (
            '/mnt/usbdisk/boot',
            '/mnt/usbdisk/EFI',
            '/mnt/usbdisk/LiveOS',
            '/mnt/usbdisk/mach_kernel',
            '/mnt/usbdisk/System',
        );

        my $error = 0;

        for my $path (@must_be_gone) {
            # test -e → 0 = exists (error), else OK
            if (script_run("test -e $path") == 0) {
                $error++;
            }
        }

        if ($error > 0) {
            assert_script_run("ls -l /mnt/usbdisk");
            wait_still_screen(5);
            die("$error of the tested data structures on the USB disk have not been deleted.");
        }
    }
    else {
        die("Unknown mode '$mod' in confirm_disk_modification");
    }

    assert_script_run("umount /mnt/usbdisk");
}

1;
