package mock;

use strict;

use base 'Exporter';
use Exporter;

use testapi;
use utils;

our @EXPORT = qw/mock_setup/;

sub mock_setup {
    my $version = get_var("VERSION");
    my $rawrel = get_var("RAWREL");
    my $mockver = $version eq $rawrel ? "rawhide" : $version;
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
    # also the buildroot repo if applicable
    my $brrepo = get_var("BUILDROOT_REPO");
    if ($brrepo) {
        $repos .= '\n[buildroot]\nname=Buildroot repo\nbaseurl=https://kojipkgs.fedoraproject.org/repos/' . $brrepo . '/latest/\$basearch/\nenabled=1\nmetadata_expire=3600\ngpgcheck=0\nskip_if_unavailable=1\n';
    }
    $repos .= '\"\"\"';
    assert_script_run 'printf "' . $repos . '" >> /etc/mock/openqa.cfg';
    # replace metalink with mirrorlist so we don't get slow mirrors
    repos_mirrorlist "/etc/mock/templates/*.tpl";
    # upload the config so we can check it's OK
    upload_logs "/etc/mock/openqa.cfg";
}

1;
