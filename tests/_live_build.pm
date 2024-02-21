use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    my $version = get_var("VERSION");
    my $rawrel = get_var("RAWREL");
    my $branch;
    my $repoks;
    my $releasever;
    my $mockver;
    if ($version eq $rawrel) {
        $branch = "main";
        $repoks = "fedora-repo-rawhide.ks";
        $releasever = "Rawhide";
        $mockver = "rawhide";
    }
    else {
        $branch = "f${version}";
        $repoks = "fedora-repo-not-rawhide.ks";
        $releasever = $version;
        $mockver = $version;
    }
    my $advortask = get_var("ADVISORY_OR_TASK");
    my $arch = get_var("ARCH");
    my $subv = get_var("SUBVARIANT");
    my $lcsubv = lc($subv);
    my $tag = get_var("TAG");
    my $workarounds = get_workarounds;
    if (get_var("NUMDISKS") > 2) {
        # put /var/lib/mock on the third disk, so we don't run out of
        # space on the main disk. The second disk will have already
        # been claimed for the update repo.
        assert_script_run "echo 'type=83' | sfdisk /dev/vdc";
        assert_script_run "mkfs.ext4 /dev/vdc1";
        assert_script_run "echo '/dev/vdc1 /var/lib/mock ext4 defaults 1 2' >> /etc/fstab";
        assert_script_run "mkdir -p /var/lib/mock";
        assert_script_run "mount /var/lib/mock";
    }
    # install the tools we need
    assert_script_run "dnf -y install mock git pykickstart tar", 300;
    # base mock config on original
    assert_script_run "echo \"include('/etc/mock/fedora-${mockver}-${arch}.cfg')\" > /etc/mock/openqa.cfg";
    # make the side and workarounds repos and the serial device available inside the mock root
    assert_script_run 'echo "config_opts[\'plugin_conf\'][\'bind_mount_enable\'] = True" >> /etc/mock/openqa.cfg';
    assert_script_run 'echo "config_opts[\'plugin_conf\'][\'bind_mount_opts\'][\'dirs\'].append((\'/mnt/update_repo\', \'/mnt/update_repo\'))" >> /etc/mock/openqa.cfg' unless ($tag);
    assert_script_run 'echo "config_opts[\'plugin_conf\'][\'bind_mount_opts\'][\'dirs\'].append((\'/mnt/workarounds_repo\', \'/mnt/workarounds_repo\'))" >> /etc/mock/openqa.cfg' if ($workarounds);
    assert_script_run 'echo "config_opts[\'plugin_conf\'][\'bind_mount_opts\'][\'dirs\'].append((\'/dev/' . $serialdev . '\', \'/dev/' . $serialdev . '\'))" >> /etc/mock/openqa.cfg';
    my $repos = 'config_opts[\'dnf.conf\'] += \"\"\"\n';
    # add the update repo or tag repo to the config
    $repos .= '[advisory]\nname=Advisory repo\nbaseurl=file:///mnt/update_repo\nenabled=1\nmetadata_expire=3600\ngpgcheck=0\n' unless ($tag);
    $repos .= '[openqa-testtag]\nname=Tag test repo\nbaseurl=https://kojipkgs.fedoraproject.org/repos/' . "${tag}/latest/${arch}" . '\nenabled=1\nmetadata_expire=3600\ngpgcheck=0\n' if ($tag);
    # and the workaround repo
    $repos .= '\n[workarounds]\nname=Workarounds repo\nbaseurl=file:///mnt/workarounds_repo\nenabled=1\nmetadata_expire=3600\ngpgcheck=0\n' if ($workarounds);
    # also the buildroot repo, for Rawhide
    if ($version eq $rawrel) {
        $repos .= '\n[koji-rawhide]\nname=Buildroot repo\nbaseurl=https://kojipkgs.fedoraproject.org/repos/f' . $version . '-build/latest/\$basearch/\nenabled=1\nmetadata_expire=3600\ngpgcheck=0\nskip_if_unavailable=1\n';
    }
    $repos .= '\"\"\"';
    assert_script_run 'printf "' . $repos . '" >> /etc/mock/openqa.cfg';
    # replace metalink with mirrorlist so we don't get slow mirrors
    repos_mirrorlist("/etc/mock/templates/*.tpl");
    # upload the config so we can check it's OK
    upload_logs "/etc/mock/openqa.cfg";
    # now check out the kickstarts
    assert_script_run 'git clone https://pagure.io/fedora-kickstarts.git';
    assert_script_run 'cd fedora-kickstarts';
    assert_script_run "git checkout ${branch}";
    # now add the side repo or tag repo to the appropriate repo ks
    assert_script_run 'echo "repo --name=advisory --baseurl=file:///mnt/update_repo" >> ' . $repoks unless ($tag);
    assert_script_run 'echo "repo --name=openqa-testtag --baseurl=https://kojipkgs.fedoraproject.org/repos/' . "${tag}/latest/${arch}" . '" >> ' . $repoks if ($tag);
    # and the workarounds repo
    assert_script_run 'echo "repo --name=workarounds --baseurl=file:///mnt/workarounds_repo" >> ' . $repoks if ($workarounds);
    # and the buildroot repo, for Rawhide
    if ($version eq $rawrel) {
        assert_script_run 'echo "repo --name=koji-rawhide --baseurl=https://kojipkgs.fedoraproject.org/repos/f' . $version . '-build/latest/\$basearch/" >> ' . $repoks;
    }
    # now flatten the kickstart
    assert_script_run "ksflatten -c fedora-live-${lcsubv}.ks -o openqa.ks";
    # FIXME: we need to patch out anaconda-webui on the fly to test
    # the g-i-s update that drops webui support, as we can't merge the
    # kickstart change till that update is stable. remove when this
    # little catch-22 is resolved
    assert_script_run "sed -i -e '/anaconda-webui/d' openqa.ks" if ($advortask eq "FEDORA-2024-8b66f08f0b");
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
