use base "installedtest";
use strict;
use mock;
use testapi;
use utils;

sub run {
    my $self = shift;
    my $version = get_var("VERSION");
    my $rawrel = get_var("RAWREL");
    my $branch;
    my $repoks;
    my $releasever;
    if ($version eq $rawrel) {
        $branch = "main";
        $repoks = "fedora-repo-rawhide.ks";
        $releasever = "Rawhide";
    }
    else {
        $branch = "f${version}";
        $repoks = "fedora-repo-not-rawhide.ks";
        $releasever = $version;
    }
    my $advortask = get_var("ADVISORY_OR_TASK");
    my $arch = get_var("ARCH");
    my $subv = get_var("SUBVARIANT");
    my $lcsubv = lc($subv);
    my $tag = get_var("TAG");
    my $copr = get_var("COPR");
    my $workarounds = get_workarounds;
    # install the tools we need
    assert_script_run "dnf -y install mock git pykickstart tar", 300;
    # set up the mock config
    mock_setup;
    # now check out the kickstarts
    assert_script_run 'git clone https://pagure.io/fedora-kickstarts.git';
    assert_script_run 'cd fedora-kickstarts';
    assert_script_run "git checkout ${branch}";
    # now add the side, tag or COPR repo to the appropriate repo ks
    assert_script_run 'echo "repo --name=advisory --baseurl=file:///mnt/update_repo" >> ' . $repoks unless ($tag || $copr);
    assert_script_run 'echo "repo --name=openqa-testtag --baseurl=' . get_var("UPDATE_OR_TAG_REPO") . '" >> ' . $repoks if ($tag || $copr);
    # and the workarounds repo
    assert_script_run 'echo "repo --name=workarounds --baseurl=file:///mnt/workarounds_repo" >> ' . $repoks if ($workarounds);
    # and the buildroot repo, for Rawhide
    if ($version eq $rawrel) {
        assert_script_run 'echo "repo --name=koji-rawhide --baseurl=https://kojipkgs.fedoraproject.org/repos/f' . $version . '-build/latest/\$basearch/" >> ' . $repoks;
    }
    # now flatten the kickstart
    assert_script_run "ksflatten -c fedora-live-${lcsubv}.ks -o openqa.ks";
    # upload the kickstart so we can check it
    upload_logs "openqa.ks";
    # now install the tools into the mock
    assert_script_run "mock -r openqa --isolation=simple --install bash coreutils glibc-all-langpacks lorax-lmc-novirt selinux-policy-targeted shadow-utils util-linux", 900;
    # now make the image build directory inside the mock root and put the kickstart there
    assert_script_run 'mock -r openqa --isolation=simple --chroot "mkdir -p /chroot_tmpdir"';
    assert_script_run "mock -r openqa --isolation=simple --copyin openqa.ks /chroot_tmpdir";
    # make sure volume ID isn't too long (for multiple Koji task cases)
    my $aot28 = substr($advortask, 0, 28);
    my $volid = "FWL-${aot28}";
    # PULL SOME LEVERS! PULL SOME LEVERS!
    assert_script_run "mock -r openqa --enable-network --isolation=simple --chroot \"/sbin/livemedia-creator --ks /chroot_tmpdir/openqa.ks --logfile /chroot_tmpdir/lmc-logs/livemedia-out.log --no-virt --resultdir /chroot_tmpdir/lmc --project Fedora-${subv}-Live --make-iso --volid ${volid} --iso-only --iso-name Fedora-${subv}-Live-${arch}-${advortask}.iso --releasever ${releasever} --macboot\"", 7200;
    unless (script_run "mock -r openqa --isolation=simple --copyout /chroot_tmpdir/lmc-logs/livemedia-out.log .", 90) {
        upload_logs "livemedia-out.log";
    }
    unless (script_run "mock -r openqa --isolation=simple --copyout /chroot_tmpdir/lmc-logs/anaconda/ anaconda", 90) {
        assert_script_run "tar cvzf anaconda.tar.gz anaconda/";
        upload_logs "anaconda.tar.gz";
    }
    assert_script_run "mock -r openqa --isolation=simple --copyout /chroot_tmpdir/lmc/Fedora-${subv}-Live-${arch}-${advortask}.iso .", 180;
    upload_asset "./Fedora-${subv}-Live-${arch}-${advortask}.iso";
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
