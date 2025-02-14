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
    my $repo = $version eq $rawrel ? "fedora-rawhide.repo" : "fedora.repo";
    my $branch;
    if ($version eq $rawrel) {
        $branch = "main";
    }
    else {
        $branch = "f${version}";
    }
    my $advortask = get_var("ADVISORY_OR_TASK");
    my $arch = get_var("ARCH");
    my $subv = get_var("SUBVARIANT");
    my $lcsubv = lc($subv);
    my $tag = get_var("TAG");
    my $copr = get_var("COPR");
    my $workarounds = get_workarounds;
    # mount our nice big empty scratch disk as /var/tmp
    assert_script_run "rm -rf /var/tmp/*";
    assert_script_run "echo 'type=83' | sfdisk /dev/vdc";
    assert_script_run "mkfs.ext4 /dev/vdc1";
    assert_script_run "echo '/dev/vdc1 /var/tmp ext4 defaults 1 2' >> /etc/fstab";
    assert_script_run "mount /var/tmp";
    assert_script_run "cd /";
    # usually a good idea for this kinda thing
    assert_script_run "setenforce Permissive";
    # install the tools we need
    assert_script_run "dnf -y install git lorax flatpak ostree rpm-ostree dbus-daemon moreutils", 480;
    # now check out workstation-ostree-config
    assert_script_run 'git clone https://pagure.io/workstation-ostree-config.git';
    assert_script_run 'pushd workstation-ostree-config';
    assert_script_run "git checkout ${branch}";
    # now copy the advisory, workaround repo and buildroot repo config files
    assert_script_run 'cp /etc/yum.repos.d/workarounds.repo .' if ($workarounds);
    assert_script_run 'cp /etc/yum.repos.d/buildroot.repo .' if ($brrepo);
    assert_script_run 'cp /etc/yum.repos.d/advisory.repo .' unless ($tag || $copr);
    assert_script_run 'cp /etc/yum.repos.d/openqa-testtag.repo .' if ($tag || $copr);
    # and add them to the config file
    my $repl = 'repos:';
    $repl .= '\n  - workarounds' if ($workarounds);
    $repl .= '\n  - buildroot' if ($brrepo);
    $repl .= '\n  - advisory' unless ($tag || $copr);
    $repl .= '\n  - openqa-testtag' if ($tag || $copr);
    # Just add them to all config files, as the names change a lot
    assert_script_run 'sed -i -e "s,repos:,' . $repl . ',g" *.yaml';
    # ensure python3-dnf is in the built ostree for _advisory_post
    # f41+
    script_run 'sed -i -e "s,packages:,packages:\n  - python3-dnf,g" *-packages.yaml';
    # <f41
    script_run 'sed -i -e "s,packages:,packages:\n  - python3-dnf,g" *-pkgs.yaml';
    # change the ref name to a custom one (so we can test rebasing to
    # the 'normal' ref later)
    assert_script_run 'sed -i -e "s,ref: fedora/,ref: fedora-openqa/,g" *.yaml';
    assert_script_run 'popd';
    # now make the ostree repo
    assert_script_run "mkdir -p /var/tmp/ostree";
    assert_script_run "ostree --repo=/var/tmp/ostree/repo init --mode=archive";
    # need this to make the pipeline in the next command fail when
    # rpm-ostree fails. note: this is a bashism
    assert_script_run "set -o pipefail";
    # PULL SOME LEVERS! PULL SOME LEVERS!
    # This shadows pungi/ostree/tree.py
    # Difference from releng: we don't pass --write-commitid-to as it
    # disables updating the ref with the new commit, and we *do* want
    # to do that. pungi updates the ref itself, I don't want to copy
    # all that work in here
    my $yaml = "$lcsubv-ostree.yaml";
    $yaml = "fedora-$lcsubv.yaml" if ($version < 41);
    assert_script_run "rpm-ostree compose tree --unified-core --repo=/var/tmp/ostree/repo/ --add-metadata-string=version=${advortask} --force-nocache /workstation-ostree-config/$yaml |& ts '" . '[%Y-%m-%d %H:%M:%S]' . "' | tee /tmp/ostree.log", 4500;
    assert_script_run "set +o pipefail";
    upload_logs "/tmp/ostree.log";
    # check out the ostree installer lorax templates
    assert_script_run 'cd /';
    assert_script_run 'git clone https://pagure.io/fedora-lorax-templates.git';
    # also check out pungi-fedora and use our script to build part of
    # the lorax command
    assert_script_run 'git clone https://pagure.io/pungi-fedora.git';
    assert_script_run 'cd pungi-fedora/';
    assert_script_run "git checkout ${branch}";
    assert_script_run 'curl --retry-delay 10 --max-time 30 --retry 5 -o ostree-parse-pungi.py https://pagure.io/fedora-qa/os-autoinst-distri-fedora/raw/main/f/ostree-parse-pungi.py', timeout => 180;
    my $loraxargs = script_output "python3 ostree-parse-pungi.py $lcsubv $arch";

    # this 'temporary file cleanup' thing can actually wipe bits of
    # the lorax install root while lorax is still running...
    assert_script_run "systemctl stop systemd-tmpfiles-clean.timer";
    # create the installer ISO
    assert_script_run "mkdir -p /var/tmp/imgbuild";
    assert_script_run "cd /var/tmp/imgbuild";

    my $cmd = "lorax -p Fedora -v ${version} -r ${version} --repo=/etc/yum.repos.d/${repo} --variant=${subv} --nomacboot --buildarch=${arch} --volid=F-${subv}-ostree-${arch}-oqa --logfile=./lorax.log ${loraxargs}";
    unless ($version > $currrel) {
        $cmd .= " --isfinal --repo=/etc/yum.repos.d/fedora-updates.repo";
    }
    $cmd .= " --repo=/etc/yum.repos.d/workarounds.repo" if ($workarounds);
    $cmd .= " --repo=/etc/yum.repos.d/buildroot.repo" if ($brrepo);
    $cmd .= " --repo=/etc/yum.repos.d/advisory.repo" unless ($tag || $copr);
    $cmd .= " --repo=/etc/yum.repos.d/openqa-testtag.repo" if ($tag || $copr);
    $cmd .= " ./results";
    assert_script_run $cmd, 9000;
    # needed for updvercheck, usually here already but not on COPR path
    assert_script_run 'dnf -y install python3-rpm', 180;
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
    upload_logs "lorax.log", failok => 1;
    assert_script_run "mv results/images/boot.iso ./${advortask}-${subv}-ostree-${arch}.iso";
    upload_asset "./${advortask}-${subv}-ostree-${arch}.iso";
}

sub test_flags {
    return {fatal => 1};
}

1;

