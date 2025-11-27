use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    # use a tty console for package setup
    $self->root_console(tty => 3);
    script_retry 'dnf -y install vulkan-tools vulkan-validation-layers', 300;
    # back to desktop
    desktop_vt;
    desktop_launch_terminal;
    assert_screen 'apps_run_terminal';
    # test vulkan layers - see
    # https://bugzilla.redhat.com/show_bug.cgi?id=2416557
    assert_script_run 'vkcube --validate --c 10', max_interval => 1;
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
