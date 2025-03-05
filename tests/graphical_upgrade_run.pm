use base "installedtest";
use strict;
use testapi;
use utils;

# This method does the basic login to a DE,
# it can distinguish between Gnome and KDE.
# We are using it to make the code a little
# lighter.
sub session_login {
    my $desktop = shift;
    my $pword = get_var("USER_PASSWORD") // "weakpassword";
    if ($desktop eq "gnome") {
        # For Gnome, we need to press Enter first
        # to show the password field, then we type
        # in the password.
        send_key("ret");
        wait_still_screen(1);
    }
    # For both DEs
    type_very_safely("$pword\n");
}

sub run {
    my $self = shift;
    my $rawrel = get_var("RAWREL");
    my $user = get_var("USER_LOGIN") // "test";
    my $pword = get_var("USER_PASSWORD") // "weakpassword";
    my $desktop = get_var("DESKTOP");

    # The previous test, 'graphical_upgrade_prerequsites' reset
    # the machine, so we will deal with booting it and
    # login to the $desktop.
    boot_to_login_screen();
    session_login($desktop);
    # If we are on Gnome, we have seen the welcome screen already
    # in the previous step, so we do not want to repeat this.
    # However, for KDE we will deal with it.
    if ($desktop eq "kde") {
        handle_welcome_screen();
    }
    # Let's check, that the desktop is shown.
    check_desktop();
    # On KDE, try and avoid double-typing issues
    if ($desktop eq "kde") {
        kde_doublek_workaround;
    }

    # Start the package manager application depending
    # on which DE we are on.
    if ($desktop eq "gnome") {
        # Do not do start checking through menu_launch_type as this
        # could fail on Gnome because of the third party dialogue.
        # Use the Software specific check instead.
        menu_launch_type("software");
        check_software_start();
    }
    else {
        menu_launch_type("discover", checkstart => 1);
    }

    # On Gnome, the upgrade is safely visible when
    # we visit the Update page by clicking on the
    # Update icon. Let's click on that icon on
    # both DEs, just to make sure.
    assert_and_click("desktop_package_tool_update");

    # Click the appropriate button to download the upgrade.
    assert_and_click("desktop_package_tool_upgrade_system", timeout => 180);

    if ($desktop eq "gnome") {
        # Restart the computer to apply upgrades, when the download is complete.
        # Downloading the upgrade packages may take a long time
        # so let's check until we find it.
        assert_and_click("desktop_package_tool_restart_upgrade", timeout => 1200);
        assert_screen("auth_required");

        # Type the password to confirm.
        type_very_safely("$pword\n");

        # Click on the 'restart and install' button
        # to restart into the upgrade session.
        assert_and_click("gnome_reboot_confirm");
    }
    elsif ($desktop eq "kde") {
        # Click on Update all
        assert_and_click("desktop_package_tool_update_apply", timeout => 1200);
        # Once we click that button, we can check the checkbutton
        # for restarting the computer automatically.
        assert_screen ["desktop_package_tool_restart_automatically", "desktop_package_tool_action_select"];
        click_lastmatch if (match_has_tag "desktop_package_tool_action_select");
        assert_and_click("desktop_package_tool_restart_automatically");
        # When we see auth_required, it means the restart has been triggered
        # and we need to authorize it
        while (!check_screen("auth_required")) {
            sleep 15;
        }
        type_very_safely("$pword\n");
    }
}


sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
