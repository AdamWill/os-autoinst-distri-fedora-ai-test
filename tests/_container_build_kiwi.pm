use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    my $version = get_var("VERSION");
    my $advortask = get_var("ADVISORY_OR_TASK");
    # we didn't use kiwi before F40, and I don't really want to write
    # an imgfac test for a release that will be dead in 6 months
    # FIXME drop when F39 is EOL
    if ($version < 40) {
        record_info('notvalid', "this test cannot be run on Fedora < 40");
        return;
    }
    my $rawrel = get_var("RAWREL");
    my $branch;
    my $repoxml;
    my $releasever;
    my $mockver;
    if ($version eq $rawrel) {
        $branch = "main";
        $repoxml = "repositories/core-rawhide.xml";
        $releasever = "Rawhide";
        $mockver = "rawhide";
    }
    else {
        $branch = "f${version}";
        $repoxml = "repositories/core-nonrawhide.xml";
        $releasever = $version;
        $mockver = $version;
    }
    my $arch = get_var("ARCH");
    my $tag = get_var("TAG");
    my $copr = get_var("COPR");
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
    assert_script_run "dnf -y install mock git", 300;
    # base mock config on original
    assert_script_run "echo \"include('/etc/mock/fedora-${mockver}-${arch}.cfg')\" > /etc/mock/openqa.cfg";
    # make the side and workarounds repos and the serial device available inside the mock root
    assert_script_run 'echo "config_opts[\'plugin_conf\'][\'bind_mount_enable\'] = True" >> /etc/mock/openqa.cfg';
    assert_script_run 'echo "config_opts[\'plugin_conf\'][\'bind_mount_opts\'][\'dirs\'].append((\'/mnt/update_repo\', \'/mnt/update_repo\'))" >> /etc/mock/openqa.cfg' unless ($tag || $copr);
    assert_script_run 'echo "config_opts[\'plugin_conf\'][\'bind_mount_opts\'][\'dirs\'].append((\'/mnt/workarounds_repo\', \'/mnt/workarounds_repo\'))" >> /etc/mock/openqa.cfg' if ($workarounds);
    assert_script_run 'echo "config_opts[\'plugin_conf\'][\'bind_mount_opts\'][\'dirs\'].append((\'/dev/' . $serialdev . '\', \'/dev/' . $serialdev . '\'))" >> /etc/mock/openqa.cfg';
    my $repos = 'config_opts[\'dnf.conf\'] += \"\"\"\n';
    # add the update, tag or COPR repo to the config
    $repos .= '[advisory]\nname=Advisory repo\nbaseurl=file:///mnt/update_repo\nenabled=1\nmetadata_expire=3600\ngpgcheck=0\n' unless ($tag || $copr);
    $repos .= '[openqa-testtag]\nname=Tag test repo\nbaseurl=' . get_var("UPDATE_OR_TAG_REPO") . '\nenabled=1\nmetadata_expire=3600\ngpgcheck=0\npriority=1\n' if ($tag || $copr);
    # and the workaround repo
    $repos .= '\n[workarounds]\nname=Workarounds repo\nbaseurl=file:///mnt/workarounds_repo\nenabled=1\nmetadata_expire=3600\ngpgcheck=0\n' if ($workarounds);
    # also the buildroot repo, for Rawhide
    if ($version eq $rawrel) {
        $repos .= '\n[koji-rawhide]\nname=Buildroot repo\nbaseurl=https://kojipkgs.fedoraproject.org/repos/f' . $version . '-build/latest/\$basearch/\nenabled=1\nmetadata_expire=3600\ngpgcheck=0\nskip_if_unavailable=1\n';
    }
    $repos .= '\"\"\"';
    assert_script_run 'printf "' . $repos . '" >> /etc/mock/openqa.cfg';
    # replace metalink with mirrorlist so we don't get slow mirrors
    repos_mirrorlist "/etc/mock/templates/*.tpl";
    # upload the config so we can check it's OK
    upload_logs "/etc/mock/openqa.cfg";
    # now check out the fedora kiwi descriptions
    assert_script_run 'git clone https://pagure.io/fedora-kiwi-descriptions.git';
    assert_script_run 'cd fedora-kiwi-descriptions';
    assert_script_run "git checkout ${branch}";
    # correct the GPG key paths in the repositories and swap metalink
    # to mirrorlist
    assert_script_run 'sed -i -e "s,/usr/share/distribution-gpg-keys/fedora,/etc/pki/rpm-gpg,g" ' . $repoxml;
    repos_mirrorlist $repoxml;
    # now add the side repo or tag repo to the appropriate repo XML
    assert_script_run 'printf "$(head -n -1 ' . $repoxml . ')\n	<repository type=\"rpm-md\" alias=\"advisory\" sourcetype=\"baseurl\">\n		<source path=\"file:///mnt/update_repo\"/>\n	</repository>\n</image>\n" > ' . $repoxml unless ($tag || $copr);
    assert_script_run 'printf "$(head -n -1 ' . $repoxml . ')\n	<repository type=\"rpm-md\" alias=\"openqa-testtag\" sourcetype=\"baseurl\">\n		<source path=\"' . get_var("UPDATE_OR_TAG_REPO") . '\"/>\n	</repository>\n</image>\n" > ' . $repoxml if ($tag || $copr);
    # and the workarounds repo
    assert_script_run 'printf "$(head -n -1 ' . $repoxml . ')\n	<repository type=\"rpm-md\" alias=\"workarounds\" sourcetype=\"baseurl\">\n		<source path=\"file:///mnt/workarounds_repo\"/>\n	</repository>\n</image>\n" > ' . $repoxml if ($workarounds);
    # and the buildroot repo, for Rawhide
    assert_script_run 'printf "$(head -n -1 ' . $repoxml . ')\n	<repository type=\"rpm-md\" alias=\"koji-rawhide\" sourcetype=\"baseurl\">\n		<source path=\"https://kojipkgs.fedoraproject.org/repos/f' . $version . '-build/latest/\$basearch/\"/>\n	</repository>\n</image>\n" > ' . $repoxml if ($version eq $rawrel);
    # upload the repositories XML so we can check it
    # NOTE: koji kiwi plugin does much more futzing around with the XML
    # it flattens includes, fiddles with the repos, and and messes with
    # preferences a bit. see
    # KiwiCreateImageTask.prepareDescription. but we do our own repo
    # stuff above, the preference stuff is unnecessary on Fedora, and
    # the flattening is unnecessary outside Koji
    upload_logs "$repoxml";
    assert_script_run "cd ..";
    # now install the tools into the mock
    assert_script_run "mock -r openqa --install kiwi-cli kiwi-systemdeps", 900;
    # now copy the descriptions in
    assert_script_run "mock -r openqa --isolation=simple --copyin fedora-kiwi-descriptions /fedora-kiwi-descriptions";
    # PULL SOME LEVERS! PULL SOME LEVERS!
    assert_script_run "mock -r openqa --enable-network --chroot \"kiwi-ng --profile Container-Base-Generic --kiwi-file Fedora.kiwi --debug --logfile /tmp/image-root.log system build --description /fedora-kiwi-descriptions/ --target-dir /builddir/result/image\"", 7200;
    unless (script_run "mock -r openqa --isolation=simple --copyout /tmp/image-root.log .", 90) {
        upload_logs "image-root.log";
    }
    assert_script_run "mock -r openqa --isolation=simple --copyout /builddir/result/image/Fedora.${arch}-${releasever}.oci.tar.xz .", 180;
    upload_asset "./Fedora.${arch}-${releasever}.oci.tar.xz";

    # load and test that we can use the built container
    assert_script_run "podman load -i ./Fedora.${arch}-${releasever}.oci.tar.xz";
    my $imgspec = "localhost/fedora:${mockver}";
    validate_script_output "podman run ${imgspec} echo Hello-World", sub { m/Hello-World/ };
    # do advisory_check_nonmatching_packages inside the container
    advisory_check_nonmatching_packages(wrapper => "podman run --rm ${imgspec}");
    # wipe the temp file so it doesn't interfere with the same check
    # on the host
    assert_script_run "rm -f /tmp/installedupdatepkgs.txt";
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
