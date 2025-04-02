use base "installedtest";
use strict;
use testapi;
use utils;

# This will try to install the selected Cantarell
# font that is installable, but not installed.

sub run {
    my $self = shift;
    # Send the TAB key until the Cantarell font is found.
    # hit tab twice as many times for silverblue, because every
    # font is shown twice:
    # https://gitlab.com/fedora/sigs/flatpak/fedora-flatpaks/-/issues/48
    my $tabs = get_var("CANNED") ? 60 : 30;
    send_key_until_needlematch("fonts_c059_font", "tab", $tabs, 1);
    click_lastmatch();
    # Check that the correct font is shown.
    assert_screen("fonts_c059_shown");
    # Click on the Install button.
    assert_and_click("gnome_button_install");
    # Because it seems that the font installation does
    # not work as expected and this has been reported
    # as https://gitlab.gnome.org/GNOME/gnome-font-viewer/-/issues/64
    # we will only softfail when this happens.
    unless (check_screen("fonts_c059_installed", timeout => 120)) {
        record_soft_failure("The installation seems to not have fully completed, see https://gitlab.gnome.org/GNOME/gnome-font-viewer/-/issues/64.");
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
