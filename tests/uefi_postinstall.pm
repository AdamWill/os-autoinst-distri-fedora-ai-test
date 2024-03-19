use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    if (not(check_screen "root_console", 0)) {
        $self->root_console(tty => 4);
    }
    assert_screen "root_console";
    # for aarch64 non-english tests
    console_loadkeys_us;
    # this test shows if the system is booted with efi
    assert_script_run '[ -d /sys/firmware/efi/ ]';
    # if Secure Boot should be enabled, check it is; if it isn't,
    # that *probably* indicates a test system issue not a distro bug,
    # but we want to know either way
    validate_script_output('mokutil --sb-state', sub { m/SecureBoot enabled/ }) if (get_var("UEFI_SECURE"));
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
