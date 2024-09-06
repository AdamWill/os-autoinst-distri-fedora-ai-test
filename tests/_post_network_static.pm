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
    # It is possible on certain tests that the following code will be running
    # while we are inside a graphical session. In this case we need to switch
    # to the console before we proceed with the network settings.
    my $console = 0;
    unless (check_screen("root_console")) {
        $console = 1;
        $self->root_console(tty => 3);
    }

    # set up networking
    setup_tap_static($ip, $hostname);

    # If we have switched to console from a graphical
    # environment, here we come back to it.
    if ($console) {
        desktop_vt();
    }
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
