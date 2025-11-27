use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    my $password = get_var("USER_PASSWORD", "weakpassword");
    desktop_launch_terminal;
    assert_screen 'apps_run_terminal';
    # become root
    type_string "sudo su\n", max_interval => 6;
    type_string "$password\n", max_interval => 6;
    # allow user serial console access so we can do assert_script_run
    assert_script_run "chmod 666 /dev/${serialdev}", max_interval => 6;
    # install necessary packages
    script_retry 'dnf -y install vulkan-tools vulkan-validation-layers', 300;
    # test vulkan layers - see
    # https://bugzilla.redhat.com/show_bug.cgi?id=2416557
    type_string "exit\n", max_interval => 6;
    assert_script_run 'vkcube --validate --c 10', max_interval => 6;
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
