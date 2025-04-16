use base "anacondatest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->root_console(tty => 3);
    # Check that there is no 'Fedora' entry in UEFI boot manager
    validate_script_output('efibootmgr', sub { $_ !~ m/.*Fedora.*/s });
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
