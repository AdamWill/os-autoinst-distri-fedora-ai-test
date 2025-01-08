use base "installedtest";
use strict;
use testapi;

sub run {
    my $self = shift;
    $self->root_console(tty => 3, timeout => 30);
    # check that xfs is used on root partition
    assert_script_run "mount | grep 'on / type xfs'";
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
