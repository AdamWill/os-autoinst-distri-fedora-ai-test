use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    connections_connect("172.16.2.114", "rapunzel", "towertop");
    # The connection should have been established, so let's
    # check for it.
    assert_screen("anaconda_select_install_lang");
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
