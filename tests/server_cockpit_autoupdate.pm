use base "installedtest";
use strict;
use testapi;
use utils;
use packagetest;
use cockpit;

sub run {
    my $self = shift;

    # Start Cockpit
    start_cockpit(login => 1);

    # Navigate to the Update screen
    select_cockpit_update();

    # Switch on automatic updates
    assert_and_click 'cockpit_updates_auto', '', 120;
    assert_and_click 'cockpit_updates_dnf_install', '', 120;
    # from 234 onwards, we get a config screen here: "no updates",
    # "security updates only", "all updates"
    assert_and_click 'cockpit_updates_auto_all';
    assert_and_click 'cockpit_save_changes';

    # Check the default automatic settings Everyday at 6 o'clock.
    assert_screen 'autoupdate_planned_day';
    assert_screen 'autoupdate_planned_time';

    # Quit Cockpit
    quit_firefox;

    # this is a dnf4 vs. dnf5 thing
    my $relnum = get_release_number;
    my $service = $relnum > 40 ? "dnf5-automatic" : "dnf-automatic-install";
    # Check that the service has started
    assert_script_run "systemctl is-active ${service}.timer";

    # Check that it is scheduled correctly
    validate_script_output "systemctl show ${service}.timer | grep TimersCalendar", sub { $_ =~ "06:00:00" };
}

sub test_flags {
    return {always_rolllback => 1};
}

1;

# vim: set sw=4 et:
