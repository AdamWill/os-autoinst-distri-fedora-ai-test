use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    # we do everything at a graphical console because for some reason
    # system often hangs if we install packages at a VT then switch back
    my $password = get_var("USER_PASSWORD", "weakpassword");
    desktop_launch_terminal;
    assert_screen 'apps_run_terminal';
    # become root
    type_string "sudo su\n", max_interval => 6;
    sleep 2;
    type_string "$password\n", max_interval => 6;
    sleep 2;
    # allow user serial console access so we can do assert_script_run
    assert_script_run "chmod 666 /dev/${serialdev}", max_interval => 6;
    # install necessary packages
    script_retry 'dnf -y install vulkan-tools vulkan-validation-layers', 300;
    # test vulkan layers - see
    # https://bugzilla.redhat.com/show_bug.cgi?id=2416557
    type_string "exit\n", max_interval => 6;
    sleep 2;
    my $relnum = get_release_number;
    if ($relnum != 42) {
        assert_script_run 'vkcube --validate --c 10', max_interval => 6;
        return;
    }
    # FIXME special handling for expected error on F42:
    # https://bugzilla.redhat.com/show_bug.cgi?id=2418077
    # remove when F42 is EOL, *or* that bug is fixed
    my $res = script_run 'vkcube --validate --c 10 > /var/tmp/vkcubelog.txt', max_interval => 6;
    # if it exited 0 we're fine (and we can drop this whole block now)
    return unless ($res);
    # *now* we can use a VT to check the failure mode
    $self->root_console(tty => 3);
    # for debugging (this check itself, and any unexpected failures)
    upload_logs '/var/tmp/vkcubelog.txt';
    # this is the md5sum of our expected failure mode on F42:
    # WARNING : VALIDATION - Message Id Number: 582089644 | Message Id Name: WARNING-vkGetDeviceProcAddr-device
    # 	vkGetDeviceProcAddr(): pName is trying to grab vkCreateDisplayPlaneSurfaceKHR which is an instance level function
    assert_script_run 'echo "bc04b3d52198f0c42515808f27227975  /var/tmp/vkcubelog.txt" > expected.md5';
    $res = script_run 'md5sum -c expected.md5';
    if ($res) {
        die 'Unexpected output from vkcube --validate! See vkcubelog.txt';
    }
    record_soft_failure 'Expected vkCreateDisplayPlaneSurfaceKHR error - see https://bugzilla.redhat.com/show_bug.cgi?id=2418077';
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
