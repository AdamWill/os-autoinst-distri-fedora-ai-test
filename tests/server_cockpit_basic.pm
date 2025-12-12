use base "installedtest";
use strict;
use testapi;
use utils;
use cockpit;

sub run {
    my $self = shift;
    # run firefox and login to cockpit
    start_cockpit(login => 1);
    # go to the logs screen
    assert_and_click "cockpit_logs";
    # the date dropdown changes and messes with the button locations, so wait
    wait_still_screen 2;
    # set priority to info and above in case there are no errors
    assert_screen ["cockpit_logs_priority_text", "cockpit_logs_toggle_filters"];
    if (match_has_tag "cockpit_logs_toggle_filters") {
        click_lastmatch;
        assert_screen "cockpit_logs_priority_text";
    }
    click_lastmatch;
    send_key "backspace";
    send_key "backspace";
    send_key "backspace";
    send_key "backspace";
    type_string "info\n";
    wait_still_screen 5;
    # now click an entry
    if (check_screen "cockpit_logs_entry", 30) {
        click_lastmatch;
    }
    else {
        assert_and_click "cockpit_logs_entry";
        record_soft_failure "Log refresh took a long time";
    }
    # check we get to the appropriate detail screen
    unless (check_screen "cockpit_logs_detail", 30) {
        assert_screen "cockpit_logs_detail", 60;
        record_soft_failure "Accessing log entry took a long time";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
