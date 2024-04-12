use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Konversation starts.

sub run {
    my $self = shift;
    my $relnum = get_release_number;
    # neochat replaced konversation in F40+; while we're still running
    # this test on F39 the test has to handle both...
    my $app = $relnum > 39 ? 'neochat' : 'konversation';

    # Start the application
    menu_launch_type $app;
    # Connect to Freenode
    assert_and_click "${app}_connect", timeout => 60 if ($app eq 'konversation');
    # Check that it is started
    assert_screen "${app}_runs";
    # Close the application
    if ($app eq 'konversation') {
        send_key 'alt-f4';
        wait_still_screen 2;
        assert_and_click "${app}_confirm_close";
    }
    else {
        quit_with_shortcut();
    }
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
