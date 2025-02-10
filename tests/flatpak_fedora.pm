use base "installedtest";
use strict;
use testapi;
use utils;

# This script tests that the flatpak technology is correctly set up
# and that it can be used without tweaking any settings or installing
# any packages on the system.

sub run {

    my $self = shift;
    $self->root_console(tty => 3);

    # Check that that Flatpak is installed on the System.
    # If the following command succeeds, we can assume that Flatpak is installed.
    assert_script_run("flatpak --version");

    # Check that at least Fedora remote repository is properly configured
    validate_script_output("flatpak remotes", sub { m/fedora/ });

    # Check that an application exists in the repository
    validate_script_output("flatpak search gvim", sub { m/org.vim.Vim/ });

    # Check that the application can be installed.
    assert_script_run("flatpak -y install org.vim.Vim", timeout => 720);

    # Check that it is listed as installed
    assert_script_run("flatpak list | grep GVim");

    # Now, we will switch into the Desktop and we will try to run the application
    desktop_vt();
    wait_still_screen(3);
    menu_launch_type("gvim", checkstart => 1);
    # Switch off the application
    type_very_safely(":qa\n");

    # We will switch to the CLI again
    $self->root_console(tty => 3);

    ## Now, we will remove the application again.
    assert_script_run("flatpak -y remove org.vim.Vim", timeout => 240);

    # Check that it the application is not listed among installed any more.
    assert_script_run("! flatpak list | grep GVim");
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
