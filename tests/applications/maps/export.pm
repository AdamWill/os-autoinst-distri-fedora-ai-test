use base "installedtest";
use strict;
use testapi;
use utils;

# This script will test if Maps can export the map into a file.

sub run {
    my $location = shift;
    my $softfail = 0;

    # Go to menu and click on Export.
    assert_and_click("gnome_burger_menu");
    assert_and_click("maps_menu_export");

    my $relnum = get_release_number;
    # wait for the export screen to appear and settle
    assert_and_click("maps_button_export");
    wait_still_screen(2);
    # Rename the file and export it
    assert_and_click("nautilus_save_filename");
    wait_still_screen(2);
    send_key('ctrl-a');
    type_very_safely("exported-map.png");
    assert_and_click("gnome_button_save");

    # After the map has been exported, we will open
    # it in an image viewer to see that it is correct.
    #
    # Open the Image Viewer
    menu_launch_type("loupe", checkstart => 1, maximize => 1);
    # Read the file into the application.
    send_key("ctrl-o");
    assert_and_click("gnome_dirs_pictures");
    assert_and_click("maps_select_file");
    assert_and_click("gnome_button_open");
    wait_still_screen(2);

    # Check that the map resembles the saved one.
    assert_screen("maps_exported_map");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:

