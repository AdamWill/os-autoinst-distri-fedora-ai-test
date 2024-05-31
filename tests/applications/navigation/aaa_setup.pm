use base "installedtest";
use strict;
use testapi;
use utils;

# We will start two applications and save the progress.

sub run {
    my $self = shift;
    my $version = get_release_number();
    my $user = get_var("USER_LOGIN", "test");
    my $canned = get_var("CANNED");
    # Let us wait here for a couple of seconds to give the VM time to settle.
    # Starting right over might result in erroneous behavior.
    sleep(5);
    # Set the update notification timestamp
    set_update_notification_timestamp();
    # Change to root console, install a game package,
    # download testdata, and return to the desktop environment.
    $self->root_console(tty => 3);
    if ($canned) {
        assert_script_run('flatpak install -y net.sourceforge.ExtremeTuxRacer', timeout => 300);
        # On Silverblue, Totem is not installed by default. Install it.
        assert_script_run('flatpak install -y org.gnome.Totem', timeout => 300);
    }
    else {
        assert_script_run("dnf install -y extremetuxracer", timeout => 180);
    }
    assert_script_run("curl -O https://pagure.io/fedora-qa/openqa_testdata/blob/thetree/f/video/video.ogv", timeout => 120);
    # Put the downloaded video in the Videos folder
    assert_script_run("mv video.ogv /home/$user/Videos/");
    desktop_vt();
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:



