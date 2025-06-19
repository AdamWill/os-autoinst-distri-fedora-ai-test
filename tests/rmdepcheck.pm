use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    my $relnum = get_release_number;
    my $version = get_var("VERSION");
    my $arch = get_var("ARCH");
    my $tag = get_var("TAG");
    my $copr = get_var("COPR");
    boot_to_login_screen;
    $self->root_console(tty => 3);
    assert_script_run 'systemctl start serial-getty@hvc1.service' if (get_var("OFW"));
    script_run "echo 'Running on serial console...'";
    select_console("virtio-console");
    console_login();
    prepare_update_mount() unless ($tag || $copr);
    setup_repos(configs => 0);
    my $nmbaserepo;
    my $baserepo;
    if (lc($version) eq "eln") {
        $baserepo = "https://kojipkgs.fedoraproject.org/repos/eln-build/latest/${arch}";
    }
    else {
        $baserepo = "https://kojipkgs.fedoraproject.org/repos/f${relnum}-build/latest/${arch}";
    }
    if (get_workarounds($version)) {
        # er. is this right? it's hard to reason about...
        $nmbaserepo = 'file:///mnt/workarounds_repo';
    }
    assert_script_run 'cd /var/tmp';
    assert_script_run "dnf -y install zstd curl git", 300;
    assert_script_run "git clone https://codeberg.org/AdamWill/rmdepcheck.git";
    assert_script_run "cd rmdepcheck";
    my $cmd = "./rmdepcheck.py";
    $cmd .= " --nmbaserepos ${nmbaserepo}" if ($nmbaserepo);
    $cmd .= " ${baserepo} ";
    if ($tag || $copr) {
        $cmd .= get_var("UPDATE_OR_TAG_REPO");
    }
    else {
        $cmd .= 'file:///mnt/update_repo';
    }
    $cmd .= ' > /tmp/rmdepcheck.txt';
    my $res = script_run $cmd, 300;
    if ($res) {
        my $message = script_output 'cat /tmp/rmdepcheck.txt';
        $self->record_resultfile('rmdepcheck', $message, result => 'fail');
        die 'rmdepcheck failed, check previous frame for output';
    }
}


sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
