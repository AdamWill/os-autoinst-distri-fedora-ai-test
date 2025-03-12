use base "installedtest";
use strict;
use testapi;
use utils;
use packagetest;

# This test sort of covers QA:Testcase_desktop_update_notification
# and QA:Testcase_desktop_error_checks . If it fails, probably *one*
# of those failed, but we don't know which (deciphering which is
# tricky and involves likely-fragile needles to try and figure out
# what notifications we have).

sub create_user_i3_config {
    my %args = @_;
    my $login = $args{login};

    assert_script_run("mkdir -p /home/$login/.config/i3/");
    # ensure that no alias of cp prevents an existing config from being overwritten
    assert_script_run("/usr/bin/cp -f /etc/i3/config /home/$login/.config/i3/config");
    assert_script_run("sed -i '/i3-config-wizard/d' /home/$login/.config/i3/config");
    assert_script_run "chown -R $login:$login /home/$login/.config";
    assert_script_run "restorecon -vr /home/$login/.config";
}

sub run {
    my $self = shift;
    my $desktop = get_var("DESKTOP");
    my $relnum = get_release_number;
    # for the live image case, handle bootloader here
    if (get_var("BOOTFROM")) {
        do_bootloader(postinstall => 1, params => '3');
    }
    else {
        do_bootloader(postinstall => 0, params => '3');
    }
    boot_to_login_screen;
    # tty1 is used here for historic reasons, but it's not hurting
    # anything and changing it might, so let's leave it...
    $self->root_console(tty => 1);
    # ensure we actually have some package updates available
    prepare_test_packages;
    my $user = get_var('USER_LOGIN', 'test');
    if ($desktop eq 'gnome') {
        # On GNOME, move the clock forward if needed, because it won't
        # check for updates before 6am(!)
        my $hour = script_output 'date +%H';
        if ($hour < 6) {
            script_run 'systemctl stop chronyd.service ntpd.service';
            script_run 'systemctl disable chronyd.service ntpd.service';
            script_run 'systemctl mask chronyd.service ntpd.service';
            assert_script_run 'date --set="06:00:00"';
        }
        if (get_var("BOOTFROM")) {
            # Set a bunch of update checking-related timestamps to
            # two days ago or two weeks ago to try and make sure we
            # get notifications, see:
            # https://wiki.gnome.org/Design/Apps/Software/Updates#Tentative_Design
            my $now = script_output 'date +%s';
            my $yyday = $now - 2 * 24 * 60 * 60;
            my $longago = $now - 14 * 24 * 60 * 60;
            # have to log in as the user to do this
            script_run 'exit', 0;
            console_login(user => $user, password => get_var('USER_PASSWORD', 'weakpassword'));
            script_run "gsettings set org.gnome.software check-timestamp ${yyday}", 0;
            script_run "gsettings set org.gnome.software update-notification-timestamp ${longago}", 0;
            script_run "gsettings set org.gnome.software online-updates-timestamp ${longago}", 0;
            script_run "gsettings set org.gnome.software upgrade-notification-timestamp ${longago}", 0;
            script_run "gsettings set org.gnome.software install-timestamp ${longago}", 0;
            wait_still_screen 5;
            script_run 'exit', 0;
            console_login(user => 'root', password => get_var('ROOT_PASSWORD', 'weakpassword'));
        }
    }
    elsif ($desktop eq 'i3') {
        assert_script_run('dnf install -y libnotify');
        unless (get_var("BOOTFROM")) {
            $user = "liveuser";
        }
        assert_script_run("usermod -a -G dialout $user");
        create_user_i3_config(login => $user);
    }
    if ($desktop eq 'kde' && get_var("BOOTFROM")) {
        # need to login as user for this
        script_run 'exit', 0;
        console_login(user => get_var('USER_LOGIN', 'test'), password => get_var('USER_PASSWORD', 'weakpassword'));
        # unset the 'last time notification was shown' setting in case
        # it got shown during install_default_upload:
        # https://bugzilla.redhat.com/show_bug.cgi?id=2178311
        script_run 'kwriteconfig5 --file PlasmaDiscoverUpdates --group Global --key LastNotificationTime --delete', 0;
        wait_still_screen 5;
        script_run 'exit', 0;
        console_login(user => 'root', password => get_var('ROOT_PASSWORD', 'weakpassword'));
    }

    # can't use assert_script_run here as long as we're on tty1
    # we don't use isolate per:
    # https://github.com/systemd/systemd/issues/26364#issuecomment-1424900066
    type_string "systemctl start graphical.target\n";
    # we trust systemd to switch us to the right tty here
    if (get_var("BOOTFROM")) {
        my $password = get_var("USER_PASSWORD", "weakpassword");
        assert_screen 'graphical_login', 60;
        wait_still_screen 10, 30;
        dm_perform_login($desktop, $password);
    }
    check_desktop(timeout => 180);
    # now, WE WAIT. this is just an unconditional wait - rather than
    # breaking if we see an update notification appear - so we catch
    # things that crash a few minutes after startup, etc.
    for my $n (1 .. 16) {
        sleep 30;
        mouse_set 10, 10;
        send_key "spc";
        mouse_hide;
    }
    if ($desktop eq 'gnome') {
        # click the clock to show notifications. of course, we have no
        # idea what'll be in the clock, so we just have to click where
        # we know it is
        mouse_set 512, 10;
        mouse_click;
    }
    if ($desktop eq 'kde') {
        if (get_var("BOOTFROM")) {
            # first check the systray update notification is there
            assert_screen "desktop_update_notification_systray";
        }
        # now open the notifications view in the systray
        if (check_screen 'desktop_icon_notifications') {
            # this is the little bell thing KDE sometimes shows if
            # there's been a notification recently...
            click_lastmatch;
        }
        else {
            # ...otherwise you have to expand the systray and click
            # "Notifications"
            assert_and_click 'desktop_expand_systray';
            assert_and_click 'desktop_systray_notifications';
        }
        # In F32+ we may get an 'akonadi did something' message
        if (check_screen 'akonadi_migration_notification', 5) {
            click_lastmatch;
            # ...and on F42+ that makes the notification pane close
            # so we have to open it again
            if (check_screen 'desktop_expand_systray', 5) {
                click_lastmatch;
                assert_and_click 'desktop_systray_notifications';
            }
        }
    }
    if ($desktop eq 'i3') {
        # we launch a terminal so that the top of the screen is filled with
        # something that we know and can check that it is not covered by a
        # notification popup from dunst
        desktop_launch_terminal;
        assert_screen("apps_run_terminal");
        assert_script_run('notify-send -t 10000 "foo"');
        assert_screen("i3_dunst_foo_notification", timeout => 5);

        sleep 11;
        if (check_screen("i3_dunst_foo_notification")) {
            # The notifications should not be shown any more.
            record_soft_fail("i3 shows notifications longer than expected");
        }
        return;
    }
    if (get_var("BOOTFROM")) {
        # we should see an update notification and no others
        assert_screen "desktop_update_notification_only";
    }
    else {
        # for the live case there should be *no* notifications
        assert_screen "desktop_no_notifications";
    }
}


sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
