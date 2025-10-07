use base "anacondatest";
use strict;
use testapi;
use utils;
use anaconda;

sub run {
    my $self = shift;
    # Anaconda hub
    # Go to INSTALLATION DESTINATION and ensure one disk is selected.
    select_disks() unless (get_var("_ANACONDA_WEBUI"));
    # check "encrypt data" checkbox
    wait_screen_change { assert_and_click "anaconda_install_destination_encrypt_data"; };
    if (get_var("_ANACONDA_WEBUI")) {
        assert_and_click "anaconda_webui_passphrase";
    }
    else {
        assert_and_click "anaconda_spoke_done";
    }
    # type password for disk encryption
    sleep 5;
    if (get_var("SWITCHED_LAYOUT")) {
        desktop_switch_layout "ascii", "anaconda";
    }
    type_safely get_var("ENCRYPT_PASSWORD");
    wait_screen_change { send_key "tab"; };
    wait_screen_change { send_key "tab"; } if (get_var("_ANACONDA_WEBUI"));
    type_safely get_var("ENCRYPT_PASSWORD");

    if (get_var("_ANACONDA_WEBUI")) {
        assert_and_click "anaconda_webui_next";
    }
    else {
        assert_and_click "anaconda_install_destination_save_passphrase";
        # Anaconda hub
        assert_screen "anaconda_main_hub", 300;
    }
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
