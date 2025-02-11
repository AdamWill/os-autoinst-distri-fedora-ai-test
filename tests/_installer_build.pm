use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    my $version = get_var("VERSION");
    my $currrel = get_var("CURRREL");
    my $rawrel = get_var("RAWREL");
    my $brrepo = get_var("BUILDROOT_REPO");
    my $repo = "fedora.repo";
    $repo = "fedora-rawhide.repo" if ($version eq $rawrel);
    $repo = "fedora-eln.repo" if (lc($version) eq "eln");
    my $advortask = get_var("ADVISORY_OR_TASK");
    my $arch = get_var("ARCH");
    # python3-dnf is for updvercheck.py
    my $packages = "python3-dnf lorax";
    $packages .= " hfsplus-tools" if ($arch eq "ppc64le");
    assert_script_run "dnf -y install $packages", 120;
    # this 'temporary file cleanup' thing can actually wipe bits of
    # the lorax install root while lorax is still running...
    assert_script_run "systemctl stop systemd-tmpfiles-clean.timer";
    assert_script_run "mkdir -p /root/imgbuild";
    assert_script_run "pushd /root/imgbuild";
    assert_script_run "setenforce Permissive";
    # Fedora pungi config always sets rootfs size to 3GiB since F32
    my $cmd = "lorax -p Fedora -v ${version} -r ${version} --repo=/etc/yum.repos.d/${repo} --rootfs-size 3 --squashfs-only";
    unless ($version > $currrel || lc($version) eq "eln") {
        $cmd .= " --isfinal --repo=/etc/yum.repos.d/fedora-updates.repo";
    }
    if (lc($version) eq "eln") {
        $cmd .= " --variant=BaseOS --nomacboot --volid=Fedora-eln-BaseOS-${arch}";
    }
    else {
        $cmd .= " --variant=Everything --volid=Fedora-E-dvd-${arch}";
    }
    $cmd .= " --repo=/etc/yum.repos.d/workarounds.repo" if (get_workarounds);
    $cmd .= " --repo=/etc/yum.repos.d/buildroot.repo" if ($brrepo);
    $cmd .= " --repo=/etc/yum.repos.d/advisory.repo" unless (get_var("TAG") || get_var("COPR"));
    $cmd .= " --repo=/etc/yum.repos.d/openqa-testtag.repo" if (get_var("TAG") || get_var("COPR"));
    $cmd .= " ./results";
    assert_script_run $cmd, 2400;
    # do a package version check on the packages installed to the
    # installer environment - see
    # https://pagure.io/releng/failed-composes/issue/6538#comment-917347
    assert_script_run 'curl --retry-delay 10 --max-time 30 --retry 5 -o updvercheck.py https://pagure.io/fedora-qa/os-autoinst-distri-fedora/raw/lorax-check-packages/f/updvercheck.py', timeout => 180;
    my $advisory = get_var("ADVISORY");
    my $cmd = 'python3 ./updvercheck.py /mnt/updatepkgs.txt pylorax.log';
    $cmd .= " $advisory" if ($advisory);
    my $ret = script_run $cmd;
    acnp_handle_output($ret, 0, 1);
    # good to have the log around for checks
    upload_logs "pylorax.log", failok => 1;
    assert_script_run "mv results/images/boot.iso ./${advortask}-netinst-${arch}.iso";
    upload_asset "./${advortask}-netinst-${arch}.iso";
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
