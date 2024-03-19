use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    if (not(check_screen "root_console", 0)) {
        $self->root_console(tty => 4);
    }
    # now try deleting the "Fedora" boot entry and rebooting, to check the fallback path
    assert_script_run('efibootmgr -b $(efibootmgr | grep Fedora | head -1 | cut -f1 | sed -e "s,[^0-9],,g") -B');
    # check that worked
    validate_script_output('efibootmgr', sub { $_ !~ m/.*Fedora.*/s });
    type_string("reboot\n");
    boot_to_login_screen;
    $self->root_console(tty => 3);
    # Fedora entry should have been recreated
    validate_script_output('efibootmgr', sub { m/Fedora/ });
    # SB should still be enabled
    validate_script_output('mokutil --sb-state', sub { m/SecureBoot enabled/ });
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
