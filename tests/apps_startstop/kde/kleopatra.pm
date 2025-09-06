use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Kleopatra starts.

sub run {
    my $self = shift;

    # Start the application
    menu_launch_type 'kleopatra';
    # Check that the Self Test page has appeared.
    assert_screen(["kleopatra_selfcheck_page", "apps_run_kleopatra"]);
    if (match_has_tag("kleopatra_selfcheck_page")) {
        # There should be no failed tests, but since this is not the application
        # test, we will only softfail if they are failed.
        unless (check_screen("kleopatra_selfcheck_passed", timeout => 30)) {
            record_soft_failure("Kleopatra selfcheck tests do not pass!");
        }
        assert_and_click("kde_continue");
    }

    # Check that it is started
    assert_screen 'apps_run_kleopatra';
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}


1;

# vim: set sw=4 et:
