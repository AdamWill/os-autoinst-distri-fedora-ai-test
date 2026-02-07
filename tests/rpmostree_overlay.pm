use base "installedtest";
use strict;
use testapi;
use utils;

sub reboot_and_login {
    # This subroutine reboots the host, waits out the boot process and logs in.
    my $reboot_time = shift;
    enter_cmd "systemctl reboot";
    boot_to_login_screen(timeout => $reboot_time);
    console_login(user => "root", password => get_var("ROOT_PASSWORD"));
    sleep 2;
}

sub run {
    my $self = shift;
    my $reboot_time = 300;
    # switch to TTY3 for both, graphical and console tests
    $self->root_console(tty => 3);
    # disable graphical boot on graphical images
    assert_script_run "systemctl set-default multi-user.target";

    # Try and cancel any running rpm-ostree operations (GNOME Software
    # may be trying to refresh or something). This often needs to be
    # done multiple times, so let's go with 6. for some reason as of
    # 2024-01, this often takes a long time, so bump timeout
    for my $n (1 .. 6) {
        script_run "rpm-ostree cancel", timeout => 180;
    }

    # Install htop as rpm-ostree overlay. Let's have timeout defined
    # quite generously, because it loads the package DBs.
    assert_script_run "rpm-ostree install htop", timeout => 600;
    # Reboot the machine to boot into the overlayed tree.
    reboot_and_login "300";

    # Check that htop rpm is installed
    assert_script_run "rpm -q htop";
    # And that it works
    assert_script_run "htop --version";

    # Then install the psotgresql-server package.
    assert_script_run "rpm-ostree install postgresql-server", timeout => 600;

    # Reboot the machine to boot into the overlayed tree.
    reboot_and_login "300";

    # Check for new as well as old overlays
    assert_script_run "rpm -q htop";
    assert_script_run "rpm -q postgresql-server";
    # this is a dependency of postgresql-server; check it's there
    assert_script_run "rpm -q postgresql";

    # init the db (required to be able to run the service)
    assert_script_run "/usr/bin/postgresql-setup --initdb";

    # Start the postgresql.service and check for its status
    assert_script_run "systemctl start postgresql";
    assert_script_run "systemctl is-active postgresql";

    # Check it's working
    assert_script_run 'su postgres -c "psql -l"';

    # Enable the postgresql service
    assert_script_run "systemctl enable postgresql";

    # Reboot the computer to boot check if the service has been enabled and starts
    # automatically.
    reboot_and_login "300";

    # See if postgresql is started
    assert_script_run "systemctl is-active postgresql";

    # Cancel running operations again
    for my $n (1 .. 6) {
        script_run "rpm-ostree cancel", timeout => 180;
    }

    # Uninstall htop and postgresql again.
    assert_script_run "rpm-ostree uninstall htop postgresql-server", timeout => 300;

    # Reboot to see the changed tree
    reboot_and_login "300";

    # Check if htop and postgresql-server were removed and no longer can be used.
    assert_script_run "! rpm -q htop";
    assert_script_run "! rpm -q postgresql-server";
    assert_script_run "! rpm -q postgresql";
    assert_script_run "! htop --version";
    assert_script_run "! systemctl is-active postgresql";

}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
