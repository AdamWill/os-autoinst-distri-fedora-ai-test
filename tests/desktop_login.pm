use base "installedtest";
use strict;
use testapi;
use utils;

our $desktop = get_var("DESKTOP");
our $syspwd = get_var("USER_PASSWORD") || "weakpassword";

sub type_password {
    # Safe typing prolongs the operation terribly.
    # Let's just use type_string and wait afterwards.
    my $string = shift;
    type_string "$string\n";
    sleep 3;
}

sub adduser {
    # Add user to the system.
    my %args = @_;
    my $name = $args{name};
    my $login = $args{login};
    my $password = $args{password};

    assert_script_run "useradd -c '$name' $login";
    assert_script_run "usermod -a -G dialout $login";
    if ($password ne "askuser") {
        # If we want to create a user with a defined password.
        assert_script_run "echo '$login:$password' | chpasswd";
    }
    else {
        # If we want to create a user without a password,
        # that forces GDM to create a password upon the
        # first login.
        assert_script_run "passwd -d $login";
        assert_script_run "chage --lastday 0 $login";
    }
    assert_script_run "grep $login /etc/passwd";
    # Create Config file for $login.
    if ($desktop eq "i3") {
        assert_script_run("mkdir -p /home/$login/.config/i3/");
        # ensure that no alias of cp prevents an existing config from being overwritten
        assert_script_run("/usr/bin/cp -f /etc/i3/config /home/$login/.config/i3/config");
        assert_script_run("sed -i '/i3-config-wizard/d' /home/$login/.config/i3/config");
        assert_script_run "chown -R $login:$login /home/$login/.config";
        assert_script_run "restorecon -vr /home/$login/.config";
    }
}

sub lock_screen {
    if ($desktop eq "i3") {
        x11_start_program("i3lock");
    }
    else {
        # Click on buttons to lock the screen.
        assert_and_click "system_menu_button";
        if ($desktop eq "kde") {
            assert_and_click "leave_button";
        }
        assert_and_click "lock_button";
    }
    wait_still_screen 10;
}

sub login_user {
    # Do steps to unlock a previously locked screen. We use it to handle
    # logins as well, because it is practically the same.
    my %args = @_;
    $args{checklogin} //= 1;
    $args{method} //= "";
    my $user = $args{user};
    my $password = $args{password};
    my $method = $args{method};
    if (($method ne 'unlock' && !check_screen "login_$user") || $desktop eq "i3") {
        # Sometimes, especially in SDDM, we do not get the user list
        # but rather a "screensaver" screen for the DM.
        # We send the Esc key to come back to the login screen.
        send_key('esc');
        wait_still_screen(stilltime => 5, similarity_level => 45);
    }
    if ($method ne "unlock") {
        # on lightdm we have to open the drop down menu to get to the user selection
        if ($desktop eq "i3") {
            assert_and_click('lightdm_user_selection');
        }
        # When we do not just want to unlock the screen, we need to select a user.
        if (check_screen "login_$user", 30) {
            click_lastmatch;
        }
        else {
            record_soft_failure "logout seems to be taking too long";
            assert_and_click "login_$user";
        }
        wait_still_screen(stilltime => 5, similarity_level => 45);
    }
    if ($method eq "create") {
        # With users that do not have passwords, we need to make an extra round
        # of password typing.
        type_very_safely "$password\n";
    }
    if (get_var('DESKTOP') eq 'i3') {
        # use essentially type_very_safely, but without wait_screen_change being
        # set, because the i3lock screen does not change enough when typing a
        # character and that just causes huge delays to unlock the screen
        type_string("$password\n", max_interval => 1);
    }
    else {
        type_very_safely "$password\n";
    }
    check_desktop(timeout => 60) if ($args{checklogin});
    wait_still_screen(stilltime => 5, similarity_level => 45);
    if ($desktop eq "kde") {
        click_lastmatch if (check_screen "getting_started");
    }
}

sub check_user_logged_in {
    # Performs a check that a correct user has been locked in.
    my %args = @_;
    $args{termopen} //= 0;
    $args{keepterm} //= 0;
    my $user = $args{user};
    # In Gnome and i3, the current user's name is not easily visible,
    # so reading the login name from the terminal prompt seems to be
    # the most reliable thing to do. In KDE we could see it on the
    # launcher menu, but it keeps things clean if we use the same
    # approach for all desktops.
    my $exitkey = "alt-f4";
    $exitkey = "shift-ctrl-q" if ($desktop eq "i3");
    desktop_launch_terminal unless ($args{termopen});
    # the leave_button check is a workaround for
    # https://bugzilla.redhat.com/show_bug.cgi?id=2335913
    assert_screen(["apps_run_terminal", "leave_button"]);
    if (match_has_tag("leave_button")) {
        send_key("esc");
        assert_screen("apps_run_terminal");
    }
    assert_script_run('[ $(whoami) = "' . "$user\" ]");
    send_key $exitkey unless ($args{keepterm});
    wait_still_screen 5;
}

sub logout_user {
    if ($desktop eq "i3") {
        send_key("alt-shift-e");
        assert_and_click("i3-logout-bar");
        assert_screen("graphical_login_input");
    } else {
        # Do steps to log out the user to reach the login screen.
        assert_and_click "system_menu_button";
        assert_and_click "leave_button";
        assert_and_click "log_out_entry";
        assert_and_click "log_out_confirm";
        wait_still_screen 5;
        sleep 10;
    }
}

sub switch_user {
    # Switch the user, i.e. leave the current user logged in and
    # log in another user simultaneously.
    if (check_screen "locked_screen_switch_user", 5) {
        assert_and_click "locked_screen_switch_user";
    }
    elsif (check_screen "system_menu_button") {
        # The system_menu_button indicates that we are in an active
        # and unlocked session, where user switching differs
        # from a locked but active session.
        assert_and_click "system_menu_button";
        assert_and_click "leave_button";
        assert_and_click "switch_user_entry";
        wait_still_screen 5;
        # Add sleep to slow down the process a bit
        sleep 10;
    }
}

sub reboot_system {
    if ($desktop eq 'i3') {
        # we are still in i3 if the bar is visible
        if (check_screen('i3-bar')) {
            logout_user();
        }
        assert_and_click('lightdm_power_menu');
        assert_and_click('lightdm_power_menu-reboot');
        assert_and_click('lightdm_power_menu-reboot-confirm');
    }

    # Reboots the system and handles everything until the next GDM screen.
    else {
        # In a logged in desktop, we access power options through system menu
        assert_and_click "system_menu_button";
        # In KDE reboot entry is right here, on GNOME we need to
        # enter some kind of power option submenu
        assert_screen ["power_entry", "reboot_entry"];
        click_lastmatch;
        assert_and_click "reboot_entry" if (match_has_tag("power_entry"));
        assert_and_click "restart_confirm";
    }
    boot_to_login_screen();
}

sub power_off {
    # Powers-off the machine.
    if (get_var('DESKTOP') eq 'i3') {
        # we are still in i3 if the bar is visible
        if (check_screen('i3-bar')) {
            logout_user();
        }
        assert_screen('lightdm_login_screen');
        send_key('alt-f4');
        assert_and_click('lightdm_power_menu-shutdown-confirm');
    }
    else {
        assert_and_click "system_menu_button";
        # in KDE since F34, there's no submenu to access, the button is right here
        assert_screen ["power_entry", "power_off_entry"];
        click_lastmatch;
        assert_and_click "power_off_entry" if (match_has_tag("power_entry"));
        assert_and_click "power_off_confirm";
    }
    assert_shutdown;
}

sub run {
    # Do a default installation of the Fedora release you wish to test. Create two user accounts.
    my $self = shift;
    my $jackpass = "kozapanijezibaby";
    my $jimpass = "babajagakozaroza";
    our $desktop = get_var("DESKTOP");
    # replace the wallpaper with a black image, this should work for
    # all desktops. Takes effect after a logout / login cycle
    $self->root_console(tty => 3);
    assert_script_run "dnf -y install GraphicsMagick", 300;
    assert_script_run "gm convert -size 1024x768 xc:black /usr/share/backgrounds/black.png";
    assert_script_run "gm convert -size 1024x768 xc:black /usr/share/backgrounds/black.webp";
    assert_script_run "gm convert -size 1024x768 xc:black /usr/share/backgrounds/black.jxl";
    if (script_run 'for i in /usr/share/backgrounds/f*/default/*.png; do ln -sf /usr/share/backgrounds/black.png $i; done') {
        # if that failed, they're probably in webp format...
        if (script_run 'for i in /usr/share/backgrounds/f*/default/*.webp; do ln -sf /usr/share/backgrounds/black.webp $i; done') {
            # ...no? jpeg xl maybe?
            assert_script_run 'for i in /usr/share/backgrounds/f*/default/*.jxl; do ln -sf /usr/share/backgrounds/black.jxl $i; done';
        }
    }
    if ($desktop eq "kde") {
        # use solid blue background for SDDM
        # theme.conf.user was dropped in 5.90.0-2.fc40, doing
        # theme.conf* should work before and after
        assert_script_run "sed -i -e 's,image,solid,g' /usr/share/sddm/themes/01-breeze-fedora/theme.conf*";
    }
    adduser(name => "Jack Sparrow", login => "jack", password => $jackpass);
    if ($desktop eq "gnome") {
        # suppress the Welcome Tour for new users in GNOME 40+
        assert_script_run 'printf "[org.gnome.shell]\nwelcome-dialog-last-shown-version=\'4294967295\'\n" > /usr/share/glib-2.0/schemas/org.gnome.shell.gschema.override';
        # Disable automatic update installation (so we don't install an update
        # to fXX-backgrounds and put the 'real' image back when we reboot)
        assert_script_run 'printf "[org.gnome.software]\ndownload-updates=false\n" > /usr/share/glib-2.0/schemas/org.gnome.software.gschema.override';
        assert_script_run 'glib-compile-schemas /usr/share/glib-2.0/schemas';
        # In Gnome, we can create a passwordless user that can provide his password upon
        # the first login. So we can create the second user in this way to test this feature
        # later.
        adduser(name => "Jim Eagle", login => "jim", password => "askuser");
    }
    else {
        # In KDE, we can also create a passwordless user, but we cannot log into the system
        # later, so we will create the second user the standard way.
        adduser(name => "Jim Eagle", login => "jim", password => $jimpass);
    }

    # Clean boot the system, and note what accounts are listed on the login screen.
    # There is no need to check specifically if the users are listed, because if they
    # are not, the login tests will fail later.
    script_run "systemctl reboot", 0;
    boot_to_login_screen;

    # Log in with the first user account.
    login_user(user => "jack", password => $jackpass);
    check_user_logged_in(user => "jack");
    # Log out the user.
    logout_user();

    # Log in with the second user account. The second account, Jim Eagle,
    if ($desktop eq "gnome") {
        # If we are in Gnome, we will this time assign a password on first log-in.
        login_user(user => "jim", password => $jimpass, method => "create");
    }
    else {
        # If not, we are in KDE and we will log in normally.
        login_user(user => "jim", password => $jimpass);
    }
    check_user_logged_in(user => "jim");
    # And this time reboot the system using the menu.
    reboot_system();

    # Try to log in with either account, intentionally entering the wrong password.
    login_user(user => "jack", password => "wrongpassword", checklogin => 0);
    my $relnum = get_release_number;
    if ($desktop eq 'i3') {
        # In LightDM (used by i3), a message is shown about an
        # unsuccessful login and it can be asserted, so let's do it.
        assert_screen "login_wrong_password";
    }
    send_key 'esc' unless (check_screen "login_jim");

    # Now, log into the system again using the correct password. This will
    # only work if we were correctly denied login with the wrong password,
    # if we were let in with the wrong password it'll fail
    login_user(user => "jim", password => $jimpass);
    check_user_logged_in(user => "jim");

    # Lock the screen and unlock again.
    lock_screen();
    # Use the password to unlock the screen.
    login_user(user => "jim", password => $jimpass, method => "unlock");

    # Switch user tests
    unless ($desktop eq "i3") {
        # Start a terminal session to monitor on which sessions we are, when we start switching users.
        # This time, we will open the terminal window manually because we want to leave it open later.
        desktop_launch_terminal;
        wait_still_screen 2;
        # Initiate switch user
        switch_user();
        # Now, we get a new login screen, so let's do the login into the new session.
        login_user(user => "jack", password => $jackpass);
        # Check that it is a new session, the terminal window should not be visible.
        if (check_screen "apps_run_terminal") {
            die "The session was not switched!";
        }
        else {
            # keep the terminal open so we can check later
            check_user_logged_in(user => "jack", keepterm => 1);
        }
        # Switch again.
        switch_user();
        # Now, let us log into the original session, this time, the terminal window
        # should still be visible.
        login_user(user => "jim", password => $jimpass);
        check_user_logged_in(user => "jim", termopen => 1);

        # We will also test another alternative - switching the user from
        # a locked screen.
        lock_screen();
        send_key "ret";
        switch_user();
        login_user(user => "jack", password => $jackpass);
        # we should be back in the previous 'jack' session so the terminal
        # we kept open should be there
        check_user_logged_in(user => "jack", termopen => 1);
    }
    # Power off the machine
    power_off();
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
