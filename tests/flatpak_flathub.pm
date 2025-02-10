use base "installedtest";
use strict;
use testapi;
use utils;

# This script tests that the Flathub repository can be added and that applications
# from that repository can be installed.

sub run {

    my $self = shift;
    $self->root_console(tty => 3);
    # Trust the SSL certificate for the proxy we use to MITM flathub
    # to reduce external traffic
    # https://pagure.io/fedora-infrastructure/issue/11634
    assert_script_run("curl -o /etc/pki/ca-trust/source/anchors/flathub-proxy.crt https://fedorapeople.org/groups/qa/openqa-data/flathub-proxy.crt");
    assert_script_run("update-ca-trust");

    # On Silverblue, Flathub is not set as a Flatpak remote by default, only when Third Party Repos
    # are enabled. To make sure, we have it enabled, we will use the following command to
    # add the Flathub repository.
    assert_script_run("sudo http_proxy=http://flatpak-cache01.iad2.fedoraproject.org:3128 flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo");

    # Check that the Flathub repository has been added into the repositories.
    validate_script_output("flatpak remotes", sub { m/flathub/ });

    # Now, we can search for an application that only exists in Flathub.
    validate_script_output("http_proxy=http://flatpak-cache01.iad2.fedoraproject.org:3128 flatpak search focuswriter", sub { m/org.gottcode.FocusWriter/ });

    # And we can install it
    assert_script_run("http_proxy=http://flatpak-cache01.iad2.fedoraproject.org:3128 flatpak install -y org.gottcode.FocusWriter", timeout => 600);

    # Check that now the application is listed in the installed flatpaks.
    assert_script_run("flatpak list | grep org.gottcode.FocusWriter");


    # Switch to desktop and try to run the application.
    desktop_vt();
    wait_still_screen(3);
    menu_launch_type("focuswriter", checkstart => 1);
    # Stop the application
    send_key("alt-f4");

    # Switch to console again.
    $self->root_console(tty => 3);

    # Now, remove the package and test that it is not listed.
    assert_script_run("flatpak remove -y org.gottcode.FocusWriter");
    assert_script_run("! flatpak list | grep org.gottcode.FocusWriter");
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
