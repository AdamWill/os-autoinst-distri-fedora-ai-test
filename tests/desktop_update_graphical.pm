use base "installedtest";
use strict;
use testapi;
use utils;
use packagetest;

sub run {
    my $self = shift;
    my $desktop = get_var('DESKTOP');
    my $relnum = get_release_number;
    # use a tty console for repo config and package prep
    $self->root_console(tty => 3);
    disable_updates_repos;
    # for update tests, disable koji-rawhide at this point, otherwise
    # gnome-software will complain about things being unsigned even
    # though the repo has gpgcheck=0
    if (get_var("ADVISORY_OR_TASK") && get_var("VERSION") eq get_var("RAWREL")) {
        assert_script_run 'sed -i -e "s,enabled=1,enabled=0,g" /etc/yum.repos.d/koji-rawhide.repo';
    }
    prepare_test_packages;
    # get back to the desktop
    desktop_vt;

    # run the updater
    if ($desktop eq 'kde') {
        # try and avoid double-typing issues, same way we do
        # for apps_startstop test
        wait_screen_change { send_key 'super'; };
        wait_still_screen 3;
        send_key "k";
        wait_still_screen 5;
        send_key "esc";
        menu_launch_type('discover');
        # Wait for it to run and maximize it to make sure we see the
        # Updates entry
        assert_screen('discover_runs');
        wait_still_screen 2;
        wait_screen_change { send_key "super-pgup"; };
        wait_still_screen 2;
    }
    else {
        # this launches GNOME Software on GNOME, dunno for any other
        # desktop yet
        sleep 3;
        menu_launch_type('update');
    }
    # GNOME Software 44+ has a 3rd party source pop-up, get rid of it
    # if it shows up (but don't fail if it doesn't, we're not testing that)
    if ($desktop eq 'gnome' && check_screen 'gnome_software_ignore', 10) {
        # keep clicking till we hit it, it tends to wobble around,
        # especially with GNOME 46 - part of
        # https://gitlab.gnome.org/GNOME/gnome-software/-/issues/2442
        click_lastmatch;
        wait_still_screen 2;
        my $count = 20;
        while (check_screen 'gnome_software_ignore', 3) {
            die "couldn't get rid of ignore screen!" if ($count == 0);
            $count -= 1;
            click_lastmatch;
            wait_still_screen 2;
        }
    }
    # go to the 'update' interface. We may be waiting some time at a
    # 'Software catalog is being loaded' screen.
    for my $n (1 .. 5) {
        last if (check_screen 'desktop_package_tool_update', 120);
        mouse_set 10, 10;
        mouse_hide;
    }
    if ($desktop eq 'gnome') {
        # wait for it to settle, it seems to take a long time and sometimes
        # go into 'app is not responding' mode - part of
        # https://gitlab.gnome.org/GNOME/gnome-software/-/issues/2442
        wait_still_screen 10;
        # try to click in a 'neutral' area of the UI to get rid of the
        # weird 'short window' state - another part of
        # https://gitlab.gnome.org/GNOME/gnome-software/-/issues/2442
        mouse_set 36, 128;
        mouse_click;
    }
    assert_and_click 'desktop_package_tool_update';
    # wait for things to settle if e.g. GNOME is refreshing
    wait_still_screen 5, 90;
    # we always want to refresh to make sure we get the prepared update
    assert_and_click 'desktop_package_tool_update_refresh', timeout => 120;
    # for GNOME, the apply/download buttons remain visible for a long
    # time, annoyingly. So let's actually watch the 'refreshing' state
    # till it goes away
    if ($desktop eq 'gnome') {
        assert_screen 'desktop_package_tool_update_refreshing';
        # now wait for it to go away
        for my $n (1 .. 30) {
            last unless (check_screen 'desktop_package_tool_update_refreshing', 6);
            # if we matched, we likely matched *immediately*, so sleep
            # the other five seconds
            sleep 5;
        }
        sleep 3;
    }
    else {
        # just wait a bit to make sure the UI clears to a 'refreshing'
        # state
        sleep 5;
    }

    my $tags = ['desktop_package_tool_update_download', 'desktop_package_tool_update_apply'];    # testtag

    # Apply updates, moving the mouse every two minutes to avoid the
    # idle screen blank kicking in. Depending on whether this is KDE
    # or GNOME and what Fedora release, we may see 'apply' right away,
    # or 'download' then 'apply'
    for (my $n = 1; $n < 6; $n++) {
        if (check_screen $tags, 120) {
            # if we see 'apply', we're done here, quit out of the loop
            last if (match_has_tag 'desktop_package_tool_update_apply');
            # if we see 'download', let's hit it, and continue waiting
            # for apply (only)
            wait_screen_change { click_lastmatch; };
            $n -= 1 if ($n > 1);
            if (get_var("TAG") || get_var("COPR")) {
                # we might get a 'download unsigned software' prompt
                # https://gitlab.gnome.org/GNOME/gnome-software/-/issues/2246
                click_lastmatch if (check_screen "desktop_package_tool_update_download_unsigned", 30);
            }
            $tags = ['desktop_package_tool_update_apply'];
            next;
        }
        # move the mouse to stop the screen blanking on idle
        mouse_set 10, 10;
        mouse_hide;
    }
    # Magic wait, clicking this right after the last click sometimes
    # goes wrong
    wait_still_screen 5;
    assert_and_click 'desktop_package_tool_update_apply';
    # on GNOME, wait for reboots.
    if ($desktop eq 'gnome') {
        # handle reboot confirm screen which pops up when user is
        # logged in (but don't fail if it doesn't as we're not testing
        # that)
        if (get_var("TAG") || get_var("COPR")) {
            # we might get a 'download unsigned software' prompt
            # https://gitlab.gnome.org/GNOME/gnome-software/-/issues/2246
            click_lastmatch if (check_screen "desktop_package_tool_update_download_unsigned", 5);
        }
        if (check_screen 'gnome_reboot_confirm', 15) {
            send_key 'tab';
            send_key 'ret';
        }
        boot_to_login_screen;
    }
    elsif ($desktop eq 'kde') {
        assert_and_click 'kde_offline_update_reboot';
        boot_to_login_screen;
    }
    # back to console to verify updates
    $self->root_console(tty => 3);
    verify_updated_packages;
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
