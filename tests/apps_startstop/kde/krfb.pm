use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Krfb starts.

sub run {
    my $self = shift;

    # Start the application
    menu_launch_type 'krfb';
    # Check that it is started
    assert_screen ['apps_run_krfb', 'kde_cancel_button'], timeout => 60;
    # we may see *two* cancel buttons - one for remote control
    # permissions, one for kwallet
    if (match_has_tag 'kde_cancel_button') {
        click_lastmatch;
        assert_screen ['apps_run_krfb', 'kde_cancel_button'];
        if (match_has_tag 'kde_cancel_button') {
            click_lastmatch;
            assert_screen 'apps_run_krfb';
        }
    }
    wait_still_screen(3);
    # close the "remote control requested" window if shown
    send_key "esc";
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
