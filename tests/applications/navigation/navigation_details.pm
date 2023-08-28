use base "installedtest";
use strict;
use testapi;
use utils;

# This will test that user can trigger a detailed view of the
# navigation icons using the ~ key.

sub run {
    my $self = shift;
    # Let us wait here for a couple of seconds to give the VM time to settle.
    # Starting right over might result in erroneous behavior.
    sleep(5);

    # If we are at Nautilus switch to editor
    if (check_screen("apps_run_files")) {
        send_key("alt-tab");
        assert_screen "apps_run_editor";
    }

    # Use alt-tab to navigate to the other
    # application, but trigger the overview
    # page as well and make sure it is shown.
    hold_key("alt");
    send_key("tab");
    send_key("~");
    assert_screen("navigation_details_shown");
    release_key("alt");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:



