use base "installedtest";
use strict;
use testapi;
use tapnet;
use utils;

sub run {
    my $self = shift;
    # stop greenboot to avoid
    # https://bugzilla.redhat.com/show_bug.cgi?id=2396605
    if (get_var("SUBVARIANT") eq "IoT") {
        script_run "systemctl stop greenboot-set-rollback-trigger.service greenboot-healthcheck.service";
    }
    my ($ip, $hostname) = split(/ /, get_var("POST_STATIC"));
    $hostname //= 'localhost.localdomain';
    # set up networking
    setup_tap_static($ip, $hostname);
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
