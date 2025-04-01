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
    die("Unsigned package(s) found!") unless (script_run 'rpm -qa --queryformat "%{NAME} %{RSAHEADER:pgpsig}\n" | grep -v gpg-pubkey | grep "(none)"');
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
