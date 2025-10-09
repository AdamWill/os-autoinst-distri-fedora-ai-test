use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $relnum = get_release_number;
    my $language = get_var("LANGUAGE");
    my $im = get_var("INPUT_METHOD");
    my $switched = get_var("SWITCHED_LAYOUT");
    # give GNOME a minute to settle
    wait_still_screen 5;
    if ($im && !check_screen ['gnome_layout_native', 'gnome_layout_ascii']) {
        if (get_var("LIVE")) {
            record_soft_failure "g-i-s should have done this already - https://bugzilla.redhat.com/show_bug.cgi?id=2402147";
        }
        # since g-i-s new user mode was dropped and the replacement
        # doesn't do input method selection, and anaconda never has,
        # on the Server netinst path we have to set up the input
        # method manually:
        # https://gitlab.gnome.org/GNOME/gnome-shell/-/issues/3749
        # we also have to do this for live installs until
        # https://bugzilla.redhat.com/show_bug.cgi?id=2402147
        # is fixed
        # 'hotkey' seems to be the only thing we can type for which
        # the 'keyboard' pane is the top result; searching for
        # 'keyboard' or 'input' gives us results for uninstalled apps
        # from Software
        menu_launch_type "hotkey";
        unless (check_screen "desktop_add_input_source", 30) {
            # first attempt to run this often fails for some reason
            check_desktop;
            menu_launch_type "hotkey";
        }
        assert_and_click "desktop_add_input_source";
        assert_and_click "desktop_input_source_${language}";
        assert_and_click "desktop_input_source_${language}_${im}";
        send_key "ret";
        wait_still_screen 3;
        send_key "alt-f4";
    }
    desktop_switch_layout 'ascii' if ($switched || $im);
    desktop_launch_terminal;
    wait_still_screen 5;
    desktop_switch_layout 'native' if ($switched || $im);
    if ($im) {
        # test that input method works as expected
        # FIXME: if we ever want to test another IM language, make
        # this not-Japanese-specific
        type_safely "yama";
        assert_screen "desktop_yama_hiragana";
        send_key "spc";
        assert_screen "desktop_yama_kanji";
        send_key "spc";
        assert_screen "desktop_yama_chooser";
        send_key "esc";
        send_key "esc";
        send_key "esc";
        send_key "esc";
        check_desktop;
    }
    else {
        type_very_safely 'ytrewq';
        if ($switched) {
            desktop_switch_layout 'ascii';
            type_very_safely 'ytrewq';
        }
        # ensure the characters that actually got typed match the
        # expected layout configuration; e.g. for French we should
        # see 'ytreza', for Russian we should see 'некуцйytrewq'
        assert_screen 'desktop_input_expected_string';
    }
}

sub test_flags {
    return {fatal => 1, always_rollback => 1};
}

1;

# vim: set sw=4 et:
