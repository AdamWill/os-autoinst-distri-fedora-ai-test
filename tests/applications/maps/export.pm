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
    # the export flow was changed in gnome-maps 47. Releases earlier
    # than Rawhide and, for now, the flatpak build are still 46, so
    # we use the older flow there
    # FIXME!
    # Update on 10/15/2024:
    # Flatpakked app now uses the new flow, so the only need is for
    # older releases.
    if ($relnum < 41) {
        # old flow
        # wait for the export screen to appear and settle
        assert_screen('maps_button_export');
        wait_still_screen(2);
        # Rename the file and export it.
        # The name entry field should have focus already, so we are
        # just going to rename the proposed file name.
        send_key('ctrl-a');
        type_very_safely('exported-map.png');
        assert_and_click('maps_button_export');
    }
    else {
        # new flow
        # wait for the export screen to appear and settle
        assert_and_click("maps_button_export");
        wait_still_screen(2);
        # Rename the file and export it
        assert_and_click("nautilus_save_filename");
        type_very_safely("exported-map");
        assert_and_click("gnome_button_save");
    }

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

