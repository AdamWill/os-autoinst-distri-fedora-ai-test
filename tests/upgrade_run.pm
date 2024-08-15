use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    my $relnum = get_release_number;
    my $rawrel = get_var("RAWREL");
    # disable screen blanking (download can take a long time)
    script_run "setterm -blank 0";

    # use compose repo (compose tests) or set up update repo (update tests)
    cleanup_workaround_repo;
    repo_setup();
    my $params = "-y --releasever=${relnum}";

    if (script_run "dnf ${params} system-upgrade download", 6000) {
        record_soft_failure "dnf failed so retry with --allowerasing";
        $params .= " --allowerasing";
        assert_script_run "dnf ${params} system-upgrade download", 6000;
    }

    upload_logs "/var/log/dnf.log", failok => 1;
    upload_logs "/var/log/dnf5.log", failok => 1;
    upload_logs "/var/log/dnf.rpm.log", failok => 1;

    script_run "dnf -y system-upgrade reboot", 0;
    # fail immediately if we see a DNF error message, but keep an eye
    # out for the bootloader so we can handle it if requested
    check_screen ["upgrade_fail", "bootloader"], 15;
    die "DNF reported failure" if (match_has_tag "upgrade_fail");

    # handle bootloader, if requested; set longer timeout as sometimes
    # reboot here seems to take a long time
    if (get_var("GRUB_POSTINSTALL")) {
        do_bootloader(postinstall => 1, params => get_var("GRUB_POSTINSTALL"), timeout => 120);
    }

    # decrypt, if encrypted
    if (get_var("ENCRYPT_PASSWORD")) {
        boot_decrypt(120);
        # in encrypted case we need to wait a bit so postinstall test
        # doesn't bogus match on the encryption prompt we just completed
        # before it disappears from view
        sleep 5;
    }
}


sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
