use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks that Contacts starts.

sub run {
    my $self = shift;

    # Start the application
    start_with_launcher('apps_menu_contacts');
    # Click through setup page
    assert_and_click("contacts_select_local_addressbook");
    assert_and_click("gnome_button_done");
    # Check that is started
    assert_screen 'apps_run_contacts';
    # Register application
    register_application("gnome-contacts");
    # Close the application
    quit_with_shortcut();
}

sub test_flags {
    return {};
}

1;

# vim: set sw=4 et:
