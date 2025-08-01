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
    # for update tests, disable buildroot repo at this point, otherwise
    # gnome-software will complain about things being unsigned even
    # though the repo has gpgcheck=0
    if (get_var("BUILDROOT_REPO")) {
        assert_script_run 'sed -i -e "s,enabled=1,enabled=0,g" /etc/yum.repos.d/buildroot.repo';
    }
    # fwupd causes problems sometimes, and we're not testing it
    script_run "systemctl stop fwupd.service";
    script_run "systemctl mask fwupd.service";
    prepare_test_packages;
    # get back to the desktop
    desktop_vt;

    # run the updater
    if ($desktop eq 'kde') {
        # try and avoid double-typing issues
        kde_doublek_workaround(key => 'd');
        menu_launch_type('discover', checkstart => 1, maximize => 1);
    }
    else {
        # this launches GNOME Software on GNOME, dunno for any other
        # desktop yet
        sleep 3;
        menu_launch_type('update');
    }
    # GNOME Software 44+ has a 3rd party source pop-up, get rid of it
    # if it shows up (but don't fail if it doesn't, we're not testing that)
    if ($desktop eq 'gnome' && check_screen 'gnome_software_ignore', 15) {
        wait_still_screen 3;
        # match again as the dialog may have moved a bit
        assert_and_click 'gnome_software_ignore';
    }
    # go to the 'update' interface. We may be waiting some time at a
    # 'Software catalog is being loaded' screen.
    for my $n (1 .. 5) {
        last if (check_screen 'desktop_package_tool_update', 120);
        mouse_set 10, 10;
        mouse_hide;
    }
    # wait out a possible animation
    wait_still_screen 5;
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
            # if we have a download button, we want to hit it, even if
            # we also have a restart button. then continue waiting for
            # apply (only)
            if (check_screen 'desktop_package_tool_update_download') {
                wait_screen_change { click_lastmatch; };
                $n -= 1 if ($n > 1);
                if (get_var("TAG") || get_var("COPR")) {
                    # we might get a 'download unsigned software' prompt
                    # https://gitlab.gnome.org/GNOME/gnome-software/-/issues/2246
                    click_lastmatch if (check_screen "desktop_package_tool_update_download_unsigned", 30);
                }
                # If there is an issue and Software reports it, let us click
                # "Details" to see what the problem was to make later
                # troubleshooting easier.
                record_info("Details button", "If subject is shown but no details appeared, you might want to update the software_button_details needle.");
                if (check_screen("software_button_details", timeout => 30)) {
                    click_lastmatch();
                }
                $tags = ['desktop_package_tool_update_apply'];
                next;
            }
            # if we *only* saw apply, we're done, break out
            last;
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
        # this makes it faster when the confirm screen has a timeout,
        # and avoids the test failing if it doesn't:
        # https://invent.kde.org/plasma/discover/-/merge_requests/899
        click_lastmatch if (check_screen 'kde_offline_update_reboot_confirm', 10);
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
