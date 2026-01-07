use base "installedtest";
use strict;
use testapi;
use utils;

# This script install necessary packages and create a mount point
# to mount the USB flash disk.

sub run {
    my $self = shift;
    my $variant = get_var("SUBVARIANT");
    # Switch to console
    $self->root_console(tty => 3);

    # Install the necessary packages, for Silverblue we need to use
    # the toolbox to do it.
    if ($variant ne "Silverblue") {
        assert_script_run("dnf install -y isomd5sum", timeout => 120);
    }
    else {
        toolbox("create");
        toolbox("install", "isomd5sum");
    }

    # Create a mountpoint to mount the USB.
    assert_script_run("mkdir -p /mnt/usbdisk");

    # Show the current device layout
    assert_script_run("lsblk");

    # Exit the terminal
    desktop_vt;

}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
