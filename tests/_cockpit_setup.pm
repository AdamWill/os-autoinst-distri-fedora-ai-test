use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    # for update testing, ensure the update repos are set up
    repo_setup if (get_var("ADVISORY_OR_TASK"));
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
