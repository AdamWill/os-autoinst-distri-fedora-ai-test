use base "installedtest";
use strict;
use tapnet;
use testapi;
use utils;

sub run {
    my $self = shift;
    boot_to_login_screen(timeout => 300);
    $self->root_console(tty => 3);
    setup_tap_static('172.16.2.115', 'rdp002.test.openqa.fedoraproject.org');
    # test test: check if we can see the server
    assert_script_run "ping -c 2 172.16.2.114";
    # We try to connect through Connections which should
    # be installed by default, however if this is not
    # the case, we do not want the test to fail, so we will
    # install the app and record a soft failure.
    if (script_run("rpm -qa | grep gnome-connections", timeout => 30)) {
        assert_script_run("dnf install -y gnome-connections", timeout => 120);
        record_soft_failure("Gnome Connections are not installed.");
    }
    desktop_vt;
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
