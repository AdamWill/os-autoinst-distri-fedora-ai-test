use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    my $release = get_release_number;
    my $rawrel = get_var("RAWREL");
    my $curr = get_var("TEST") =~ "upgrade_2" ? get_var("UP2REL") : get_var("UP1REL");
    my $desktop = get_var("DESKTOP");
    my $user = get_var("USER_LOGIN", "test");
    my $pword = get_var("USER_PASSWORD", "weakpassword");

    # As this is designed, the 'upgrade_preinstall' test script
    # runs before this one and ends on the root console. Therefore,
    # we can assume that we are still on that root console, so
    # we can safely use script assertions.

    # Make serial console writable for everyone, so that we
    # can use script assertions for further commands as well.
    assert_script_run("chmod 666 /dev/${serialdev}");

    if ($desktop eq "gnome") {
        # Install Gnome specific packages
        assert_script_run("dnf install -y jq dbus-x11");
        # Leave the CLI and come back to the login screen.
        desktop_vt();
        # Log onto the graphical session
        send_key("ret");
        wait_still_screen(1);
        type_very_safely("$pword\n");
        handle_welcome_screen();
        check_desktop();
        # After the login, let us wait that everything settles
        # and that we are not too quick on the system.
        wait_still_screen(5);
        # According to the ticket, the 'fedora.json' file
        # which lists the available versions will be created
        # after the Software starts. Let's start it then on Gnome.
        # Do not use the default start checks, because they could
        # fail, check manually instead.
        menu_launch_type("software");
        check_software_start();

        # When Software is started for the first time, it asks whether
        # a user wants to use Third Party software. We want to Ignore
        # this and proceed, so if we see that we click on Ignore.
        if (check_screen("gnome_software_ignore", timeout => 60)) {
            click_lastmatch();
        }
        # Wait a couple of second, just in case the file needs a little
        # longer to be created.
        sleep(10);
        # Close Software
        send_key("alt-f4");
    }

    # Switch back to the CLI for further settings.
    $self->root_console(tty => 3);

    # For Gnome desktop only.
    if ($desktop eq "gnome") {
        # Switch to a user account
        enter_cmd("su -l $user");
        # Navigate to the version file directory
        assert_script_run("cd ~/.cache/gnome-software/fedora-pkgdb-collections");
        # Replace the word 'devel' with the Rawhide version number
        # so Rawhide behaves like other releases, if we're upgrading
        # to Rawhide
        if ($release eq $rawrel) {
            assert_script_run("jq '(.collections |= map(if .version == \"devel\" then .koji_name = \"f$rawrel\" | .version = \"$rawrel\" else . end))' fedora.json > fedora-updated.json");
            assert_script_run("mv fedora-updated.json fedora.json");
        }
        # Now make sure the versions we're trying to upgrade from and to
        # are both 'active'
        assert_script_run("jq '(.collections |= map(if .version == \"$release\" or .version == \"$curr\" then .status = \"Active\" else . end))' fedora.json > fedora-updated.json");
        assert_script_run("mv fedora-updated.json fedora.json");
        # upload the modified file for debugging
        upload_logs("fedora.json", failok => 1);

        # Disable blanking the screen on inactivity, because if the screen gets switched off
        # we will have no way to make it active again.
        assert_script_run("dbus-launch --exit-with-session gsettings set org.gnome.desktop.screensaver idle-activation-enabled false");
        assert_script_run("dbus-launch --exit-with-session gsettings set org.gnome.desktop.screensaver lock-enabled false");
        assert_script_run("dbus-launch --exit-with-session gsettings set org.gnome.desktop.lockdown disable-lock-screen true");
        # Logout the regular user
        enter_cmd("exit");
    }
    # For KDE desktop only.
    elsif ($desktop eq "kde") {
        # Replace "rawhide" with the Rawhide version number if we're
        # upgrading to Rawhide
        assert_script_run("sed -i 's,rawhide,$rawrel,g' /usr/share/metainfo/org.fedoraproject.fedora.metainfo.xml") if ($release eq $rawrel);
        # Now mark the release we want to upgrade to as stable and
        # ensure it doesn't have a date in the future
        assert_script_run("sed -i 's,version=\"$release\" type=\".*\" date=\".*\",version=\"$release\" type=\"stable\" date=\"2025-01-01\",g' /usr/share/metainfo/org.fedoraproject.fedora.metainfo.xml");
        # Upload the modified file for debugging
        upload_logs("/usr/share/metainfo/org.fedoraproject.fedora.metainfo.xml", failok => 1);
        # Switch to the regular user
        enter_cmd("su -l $user");
        # Wipe last update notification time
        assert_script_run("kwriteconfig5 --file PlasmaDiscoverUpdates --group Global --key LastNotificationTime --delete");
        # Disable the screen locker
        assert_script_run("kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock false qdbus org.freedesktop.ScreenSaver /ScreenSaver configure");
        # Exit regular user
        enter_cmd("exit");
    }

    # Reboot system to load changes
    enter_cmd("reboot");
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
