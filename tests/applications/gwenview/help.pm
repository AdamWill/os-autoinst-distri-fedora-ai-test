use base "installedtest";
use strict;
use testapi;
use utils;

# This part tests if the application can show help.

sub run {
    my $self = shift;
    sleep 2;

    # Open the shortcuts
    send_key("f1");
    assert_screen("gwen_help_shown", timeout => 120);
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
