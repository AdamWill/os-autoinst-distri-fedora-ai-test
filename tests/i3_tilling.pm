use base "installedtest";
use strict;
use testapi;
use utils;
use i3;


sub run {
    my $desktop = get_var("DESKTOP");
    my $mod = get_i3_modifier();
    die "This test is only for the i3 desktop" unless $desktop eq "i3";

    # launch a terminal first
    send_key("$mod-ret");
    assert_screen("apps_run_terminal");

    # start pavucontrol, mousepad and check that they are split on the screen
    x11_start_program("pavucontrol");
    x11_start_program("mousepad");
    assert_screen("i3_windows_split");

    # switch to tabbed layout
    send_key("$mod-w");
    assert_screen("i3_windows_tabbed");
    send_key_until_needlematch("apps_run_terminal", "$mod-j");

    send_key("$mod-;");
    assert_screen("audio_mixer");

    send_key("$mod-;");
    assert_screen("mousepad_no_document_open");

    # switch to stacked layout
    send_key("$mod-s");
    assert_screen("i3_windows_stacked");

    send_key_until_needlematch("apps_run_terminal", "$mod-k");

    send_key("$mod-l");
    assert_screen("mousepad_no_document_open");

    send_key("$mod-l");
    assert_screen("audio_mixer");
}

1;
