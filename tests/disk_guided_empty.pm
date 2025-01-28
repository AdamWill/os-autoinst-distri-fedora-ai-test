use base "anacondatest";
use strict;
use testapi;
use anaconda;
use utils;

sub run {
    my $self = shift;
    # If we want to test graphics during installation, we need to
    # call the test suite with an "IDENTIFICATION=true" variable.
    my $identification = get_var('IDENTIFICATION');
    assert_screen ["anaconda_main_hub", "anaconda_webui_installmethod"];
    if (match_has_tag "anaconda_webui_installmethod") {
        # long term we'll want two paths through select_disks or
        # a webui_select_disks, but for now, just throw it in here
        # as it's simple on this single path
        if (get_var("NUMDISKS") > 1) {
            assert_and_click "anaconda_webui_disk_select";
            assert_and_click "anaconda_install_destination_select_disk_1";
            # since webui 16, we have to click a Select button too
            click_lastmatch if (check_screen "anaconda_webui_select");
        }
        # assume default selection is the appropriate one; if it
        # isn't, we'll fail soon enough
        wait_screen_change { assert_and_click "anaconda_webui_next"; };
        wait_still_screen 3;
        # click through the 'encrypt my data' screen
        assert_and_click "anaconda_webui_next";
        # for now, skip the self-identification checks
        return;
    }
    else {
        # Go to INSTALLATION DESTINATION and ensure one disk is selected.
        select_disks();
    }

    # updates.img tests work by changing the appearance of the INSTALLATION
    # DESTINATION screen, so check that if needed.
    if (get_var('TEST_UPDATES')) {
        assert_screen "anaconda_install_destination_updates", 30;
    }
    # Here the self identification test code is placed.
    my $branched = get_var('VERSION');
    if ($identification eq 'true' or ($branched ne "Rawhide" && lc($branched) ne "eln")) {
        # See utils.pm
        check_top_bar();
        # we don't check version or pre-release because here those
        # texts appear on the banner which makes the needling
        # complex and fragile (banner is different between variants,
        # and has a gradient so for RTL languages the background color
        # differs; pre-release text is also translated)
    }

    assert_and_click "anaconda_spoke_done";

    # Anaconda hub
    assert_screen "anaconda_main_hub", 300;

}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
