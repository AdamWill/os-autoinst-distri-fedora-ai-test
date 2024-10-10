use base "installedtest";
use strict;
use testapi;
use utils;

# This script will do the following:
#  - set up the system for paswordless connection using
#    the SSH authorized keys.
#  - open the ssh key and establish the connection
#  - store that password in the keyring
#  - reboot the system
#  - re-establish the connection, this time without the need to open the password

my $desktop = get_var("DESKTOP");
my $user = get_var("USER_LOGIN", "test");
my $pass = get_var("USER_PASSWORD", "weakpassword");

sub export_kde_vars {
    # On KDE, it is possible to update and reuse the keyring
    # on Konsole if correct environmental variables are set.
    # Set them now.
    enter_cmd('export SSH_ASKPASS=/usr/bin/ksshaskpass');
    sleep 2;
    enter_cmd('export SSH_ASKPASS_REQUIRE=prefer');
    sleep 2;
}

sub connect_localhost {
    my $type = shift;

    # Start the terminal application
    desktop_launch_terminal;
    assert_screen("apps_run_terminal");
    # On KDE also export the variables
    export_kde_vars() if (get_var("DESKTOP") eq "kde");

    # Establish the SFTP connection to the localhost.
    # A dialogue should appear to collect credentials to open
    # the SSH key.
    my $command = "sftp $user" . '@localhost';
    enter_cmd($command);

    # When connecting for the first time, we will remember
    # the key password and store it in the keyring.
    if ($type ne "reconnect") {
        assert_screen("keyring_askpass_yesno");
        type_very_safely("yes\n");
        assert_screen("keyring_askpass_remember");
        type_very_safely("sshpassword");
        click_lastmatch;
        assert_and_click("keyring_askpass_confirm");
    }

    # The connection should have been established if everything has worked
    # so far.
    assert_screen("keyring_sftp_logged");
    # Finish the connection.
    enter_cmd("bye");
    # Exit the terminal app.
    enter_cmd("exit");
}

sub run {
    my $self = shift;

    # We are still at the root console and for the following steps,
    # Set up the SSH daemon

    # Authorize the SSH key.
    enter_cmd("su -l $user");
    enter_cmd('echo $(cat ~/.ssh/id_ed25519.pub) > ~/.ssh/authorized_keys');
    enter_cmd("exit");

    # Return to desktop
    desktop_vt();

    # If we arrive to a login screen, perform login
    if (check_screen("login_screen", timeout => 30)) {
        dm_perform_login($desktop, $pass);
        check_desktop;
    }

    # Use SSH to connect to the localhost.
    connect_localhost("connect");

    # Reboot the machine.
    $self->root_console(tty => 3);
    enter_cmd("reboot");
    # Log in.
    boot_to_login_screen();
    dm_perform_login($desktop, $pass);
    check_desktop(timeout => 120);

    # Reconnect without using password. We still should be
    # able to log in.
    connect_localhost("reconnect");
}

sub test_flags {
    return {fatal => 0, always_rollback => 1};
}

1;

# vim: set sw=4 et:
