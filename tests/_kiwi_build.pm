use base "installedtest";
use strict;
use mock;
use testapi;
use utils;

sub run {
    my $self = shift;
    my $version = get_var("VERSION");
    my $advortask = get_var("ADVISORY_OR_TASK");
    my $rawrel = get_var("RAWREL");
    my $brrepo = get_var("BUILDROOT_REPO");
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
    my $kiwiprofile = get_var("KIWI_PROFILE");
    my $workarounds = get_workarounds;
    my $isolation = 'nspawn';
    # lives need simple isolation and permissive selinux, sadly
    if (index($kiwiprofile, 'Live') != -1) {
        assert_script_run "setenforce Permissive";
        $isolation = 'simple';
    }
    # install the tools we need
    assert_script_run "dnf -y install mock git", 300;
    # set up the mock config
    mock_setup;
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
    # and the buildroot repo, if applicable
    assert_script_run 'printf "$(head -n -1 ' . $repoxml . ')\n	<repository type=\"rpm-md\" alias=\"buildroot\" sourcetype=\"baseurl\">\n		<source path=\"https://kojipkgs.fedoraproject.org/repos/' . $brrepo . '/latest/\$basearch/\"/>\n	</repository>\n</image>\n" > ' . $repoxml if ($brrepo);
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
    assert_script_run "mock -r openqa --isolation=${isolation} --install kiwi-cli kiwi-systemdeps", 900;
    # now copy the descriptions in
    assert_script_run "mock -r openqa --isolation=${isolation} --copyin fedora-kiwi-descriptions /fedora-kiwi-descriptions";
    # construct a volume ID of appropriate length and application ID,
    # note these don't match the official ones
    my $aot27 = substr($advortask, 0, 27);
    my $volid = "KIWI-${aot27}";
    my $appid = "${kiwiprofile}-${aot27}";
    # PULL SOME LEVERS! PULL SOME LEVERS!
    assert_script_run "mock -r openqa --isolation=${isolation} --enable-network --chroot \"kiwi-ng --profile ${kiwiprofile} --kiwi-file Fedora.kiwi --debug --logfile /tmp/image-root.log system build --description /fedora-kiwi-descriptions/ --target-dir /builddir/result/image --set-type-attr 'volid=${volid}' --set-type-attr 'application_id=${appid}'\"", 7200;
    unless (script_run "mock -r openqa --isolation=${isolation} --copyout /tmp/image-root.log .", 90) {
        upload_logs "image-root.log";
    }
    my %expected_formats = (
        'KDE-Desktop-Live' => 'iso',
        'Workstation-Live' => 'iso',
        'Container-Base-Generic' => 'oci.tar.xz'
    );
    my $format = $expected_formats{$kiwiprofile};
    my $fname = "Fedora.${arch}-${releasever}.${format}";
    assert_script_run "mock -r openqa --isolation=${isolation} --copyout /builddir/result/image/${fname} .", 180;
    if (index($kiwiprofile, 'Live') != -1) {
        # rename to the format we expect from LMC, to match that test
        # can drop this and change templates when all lives are on
        # Kiwi
        my $subv = get_var("SUBVARIANT");
        my $newfname = "Fedora-${subv}-Live-${arch}-${advortask}.iso";
        assert_script_run "mv ${fname} ${newfname}";
        $fname = $newfname;
    }
    upload_asset $fname;

    if (index($kiwiprofile, 'Container') != -1) {
        # load and test that we can use the built container
        assert_script_run "podman load -i ./${fname}";
        my $imgspec = "localhost/fedora:${mockver}";
        validate_script_output "podman run ${imgspec} echo Hello-World", sub { m/Hello-World/ };
        # do advisory_check_nonmatching_packages inside the container
        advisory_check_nonmatching_packages(wrapper => "podman run --rm ${imgspec}");
        # wipe the temp file so it doesn't interfere with the same check
        # on the host
        assert_script_run "rm -f /tmp/installedupdatepkgs.txt";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
