use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Kmag starts.

sub run {
    my $self = shift;
    # FIXME after F39 is stable, drop this test entirely
    my $relnum = get_release_number;
    return unless ($relnum < 40);

    # Start the application
    menu_launch_type 'kmag';
    # Check that it is started
    assert_screen 'kmag_runs', timeout => 60;
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
