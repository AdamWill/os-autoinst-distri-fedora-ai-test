use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $password = get_var('USER_PASSWORD', 'weakpassword');

    # launch a terminal first
    desktop_launch_terminal;
    assert_screen("apps_run_terminal");

    # Make sure to install some of the applications
    type_very_safely("sudo dnf install -y gvim mousepad\n");
    # Deal with sudo password
    type_password("$password");
    send_key("ret");
    assert_screen("i3_tiling_apps_installed");

    # start blivet_gui, mousepad and check that they are split on the screen
    x11_start_program("gvim");
    wait_still_screen(2);
    assert_screen('apps_run_gvim');
    x11_start_program("mousepad");
    assert_screen('apps_run_mousepad');
    assert_screen("i3_windows_split");

    # switch to tabbed layout
    send_key("alt-w");
    assert_screen("i3_windows_tabbed");
    send_key_until_needlematch("apps_run_terminal", "alt-j");
    wait_still_screen(2);

    send_key("alt-;");
    assert_screen("apps_run_gvim");

    send_key("alt-;");
    assert_screen("mousepad_no_document_open");

    # switch to stacked layout
    send_key("alt-s");
    assert_screen("i3_windows_stacked");

    send_key_until_needlematch("apps_run_terminal", "alt-k");

    send_key("alt-l");
    assert_screen("mousepad_no_document_open");

    send_key("alt-l");
    assert_screen("apps_run_gvim");
}

1;
