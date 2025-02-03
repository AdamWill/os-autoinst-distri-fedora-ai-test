use base "installedtest";
use strict;
use testapi;
use utils;

# This script will do the following:
# - it will establish a connection to the system via sftp
# - it will ask for password to the system and store that password
# - it will check that the password was stored in the keyring
# - it will reboot the system
# - it will re-establish the connection without asking for the password

my $user = get_var("USER_LOGIN", "test");
my $pass = get_var("USER_PASSWORD", "weakpassword");
my $desktop = get_var("DESKTOP", "gnome");

# On KDE, it is possible that Konsole interacts with keyring when
# certain variables are set in the system. This subroutine sets up
# those variables.
sub export_kde_vars {
    enter_cmd('export SSH_ASKPASS=/usr/bin/ksshaskpass');
    sleep 2;
    enter_cmd('export SSH_ASKPASS_REQUIRE=prefer');
    sleep 2;
}

# This will handle the connection to the localhost. The process is different
# for KDE and Gnome, as currently Gnome does not save passwords to keyring
# from terminal and the KDE has a bug KNetAttach that prevents Dolphin from
# establishing the connection like Nautilus does.
sub connect_localhost {
    my $type = shift;
    # For Gnome, we will use Nautilus to establish an SFTP
    # connection to the localhost.
    if (get_var("DESKTOP") eq "gnome") {
        # Start Nautilus.
        menu_launch_type("nautilus");
        assert_screen("apps_run_files");
        # Add a new network connection.
        assert_and_click("nautilus_other_locations");
        assert_and_click("nautilus_enter_address");
        my $connection = "ssh://$user" . '@localhost';
        type_very_safely("$connection\n");
        # When we connect for the first time, a password
        # dialogue should appear in which we need to type
        # in the password. We will also try to remember the
        # password and confirm the connection.
        if ($type ne "reconnect") {
            assert_screen("keyring_askpass_remember");
            type_very_safely($pass);
            click_lastmatch;
            assert_and_click("keyring_askpass_confirm");
        }
        # When the connection has been established,
        # a new connection icon will appear.
        assert_screen("nautilus_connection_established");
    }
    else {
        # On KDE, Dolphin has a bug that prevents the application
        # from connecting easily (as in Gnome). Manually, this is
        # not a big deal, as one could react accordingly, but with
        # automation, this approach is basically useless.
        # Therefore, we will use a different approach - we will enable
        # CLI keyring integration and perform an SFTP connection
        # in Konsole.
        desktop_launch_terminal;
        assert_screen("apps_run_terminal");
        # Export the environmental variables, this is needed for the process
        # to work correctly.
        export_kde_vars();
        # Connect the sftp.
        my $command = "sftp $user" . '@localhost';
        enter_cmd($command);
        # If performed for the first time, also deal with the
        # password storing which is a little painful on KDE.
        if ($type ne "reconnect") {
            # First, we check that the yes no dialogue is present
            # and type "yes" into it.
            assert_screen("keyring_askpass_yesno");
            type_very_safely("yes\n");
            # Then similarly to Gnome, the password dialogue will appear
            # and we type in the password. Also, we click on Remember
            # and confirm with the OK button.
            assert_screen("keyring_askpass_remember");
            type_very_safely("$pass");
            click_lastmatch;
            assert_and_click("keyring_askpass_confirm");
        }
        # Check that we have logged in and exit the application.
        assert_and_click("keyring_sftp_logged");
        type_very_safely("bye\n");
    }
}

sub check_stored {
    # This subroutine will run the keyring application on either
    # desktop and check that the password has been stored there.
    # On KDE, we will use the KWalletManager.
    if (get_var("DESKTOP") eq "kde") {
        menu_launch_type("kwalletmanager");
        assert_screen("apps_run_kwalletmanager");
        send_key("super-pgup");
        # Navigate to the stored entry and check
        # that the credentials are stored there.
        assert_and_dclick("keyring_wallet_passwords_unfold");
        assert_and_dclick("keyring_wallet_password_stored");
        assert_and_click("keyring_wallet_password_details");
        assert_and_click("keyring_wallet_password_reveal");
        assert_screen("keyring_wallet_password");
    }
    else {
        # Start the Seahorse application and maximize it.
        menu_launch_type("seahorse");
        assert_screen("apps_run_seahorse");
        send_key("super-up");

        # Navigate to the stored entry and check
        # that the credentials are stored there.
        assert_and_click("keyring_seahorse_login");
        assert_and_dclick("keyring_seahorse_login_details");
        assert_screen("keyring_seahorse_details_shown");
        assert_and_click("keyring_seahorse_show_password");
        assert_screen("keyring_seahorse_password_shown");
    }
}

sub run {
    my $self = shift;

    # We are still at the root console, but for the following steps,
    # there is nothing we should be doing there, so we switch back
    # to the graphical desktop.
    desktop_vt();

    if (check_screen("login_screen", timeout => 30)) {
        dm_perform_login($desktop, $pass);
        check_desktop;
    }

    # Lets connect to localhost via SSH. This should result in
    # asking for a password and storing the credentials for later use.
    # The following routine uses different approaches on different
    # desktops.
    connect_localhost("connect");
    kde_doublek_workaround if ($desktop eq "kde");
    # Check that the password has been stored.
    check_stored();

    # Reboot the machine, log onto the session again.
    $self->root_console(tty => 3);
    enter_cmd("reboot");

    # Boot to login screen and type in the password.
    boot_to_login_screen();
    dm_perform_login($desktop, $pass);
    check_desktop(timeout => 120);

    # Repeat the connection procedure, but skip the password
    # handling process as this will be done by the keyring.
    connect_localhost("reconnect");
}

sub test_flags {
    return {fatal => 0, always_rollback => 1};
}

1;

# vim: set sw=4 et:
