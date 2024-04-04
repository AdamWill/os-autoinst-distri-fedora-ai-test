use base "installedtest";
use strict;
use testapi;
use utils;

# This script will do the following:
# - install Seahorse when on Gnome
# - enable the sshd.service
# - create an SSH key for the installed user (~ test)
# - set up the SSH key password for that key
# - it will set a milestone

sub run {
    my $self = shift;
    my $desktop = get_var("DESKTOP");
    my $user = get_var("USER") || "test";

    # Switch to console to perform several setting tasks.
    $self->root_console(tty => 3);

    # Install Seahorse on Gnome.
    # On KDE, similar application is already installed in the system.
    if ($desktop eq "gnome") {
        assert_script_run("dnf -y install seahorse");
    }

    # Enable and start sshd.service and check that is is running.
    assert_script_run("systemctl enable sshd.service --now");
    assert_script_run("systemctl status sshd.service --no-pager");

    # Create the SSH keys with password for the regular user.
    # Switch to that user's account.
    assert_script_run("su $user -c 'ssh-keygen -N sshpassword -f /home/$user/.ssh/id_ed25519'");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
