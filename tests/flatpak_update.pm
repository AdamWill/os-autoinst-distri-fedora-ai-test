use base "installedtest";
use strict;
use testapi;
use utils;

# This script tests that we can update (and downgrade) flatpaks. We will
# use a test repository with a Dummy application.

sub run {

    my $self = shift;
    $self->root_console(tty => 3);
    # We will need Flathub to pull dependencies.
    # Flathub is not set as a Flatpak remote by default, only when Third Party Repos
    # are enabled. To make sure, we have it enabled, we will use the following command to
    # add the Flathub repository.
    assert_script_run("sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo", timeout => 120);
    # We will also add the test repository.
    assert_script_run("flatpak remote-add --if-not-exists flatpaktest https://lruzicka.fedorapeople.org/flatpaktest/flatpaktest.flatpakrepo", timeout => 120);

    # Install the Dummy application.
    assert_script_run("http_proxy=http://flatpak-cache01.iad2.fedoraproject.org:3128 flatpak install -y org.flatpak.Dummy", timeout => 600);
    # Check that the application has been installed
    assert_script_run("flatpak list | grep org.flatpak.Dummy");

    # The application is installed in version 2. Let's check the output.
    validate_script_output("flatpak run org.flatpak.Dummy", sub { m/Dummy flatpak: version 2/ });

    # Now, we will attempt to downgrade the application to force the previous commit
    assert_script_run("flatpak update -y --commit=37be70fa26aa652379f968a7aaf7b63fa515483b9381756cd371c8174ae68626 org.flatpak.Dummy");

    # If that was successful, the output of the application will show version 1.
    validate_script_output("flatpak run org.flatpak.Dummy", sub { m/Dummy flatpak: version 1/ });

    # Now we can update the application again, using the standard command, which will update to the
    # newest version (version 2) of the application again.
    assert_script_run("flatpak update -y org.flatpak.Dummy");
    # Let's check the application now provides the correct output.
    validate_script_output("flatpak run org.flatpak.Dummy", sub { m/Dummy flatpak: version 2/ });

    # Now, remove the package and test that it is not listed and that it cannot be run.
    assert_script_run("flatpak remove -y org.flatpak.Dummy");
    validate_script_output("flatpak list", sub { $_ !~ m/org\.flatpak\.Dummy/ });
    assert_script_run("! flatpak run org.flatpak.Dummy", sub { $_ !~ m/Dummy flatpak: version 2/ });
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
