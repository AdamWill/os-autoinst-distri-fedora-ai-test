use base "installedtest";
use strict;
use testapi;
use utils;
use packagetest;
use cockpit;

sub run {
    my $self = shift;

    my $cockdate = "0";
    # Remove a package, disable repositories and enable test repositories, install the package
    # from that repository to make the system outdated and verify that that package was
    # correctly installed.
    prepare_test_packages;
    verify_installed_packages;

    # Start Cockpit
    start_cockpit(login => 1);
    # Navigate to update screen
    select_cockpit_update();


    # Install the rest of the updates, or any updates
    # that have not been previously installed.
    assert_screen 'cockpit_updates_all_install';
    # it seems like sometimes the refresh process clears briefly then
    # comes back, so we'll wait it out
    # https://github.com/cockpit-project/cockpit/issues/22064
    wait_still_screen 3;
    assert_and_click 'cockpit_updates_all_install';
    my $run = 0;
    while ($run < 40) {
        last if (check_screen("cockpit_updates_updated"));
        # Ignore rebooting the system because we want to finish the test instead.
        if (check_screen('cockpit_updates_restart_ignore', 1)) {
            assert_and_click 'cockpit_updates_restart_ignore';
            last;
        }
        else {
            sleep 10;
            $run = $run + 1;
        }
    }
    # Check that the system is updated
    assert_screen 'cockpit_updates_updated';

    # Switch off Cockpit
    quit_firefox;

    # Verify that the test package was updated correctly.
    verify_updated_packages;
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
