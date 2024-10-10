use base "installedtest";
use strict;
use testapi;
use utils;

# This test cases automates Testcase_default_font_installation, see
# https://fedoraproject.org/wiki/QA:Testcase_default_font_installation

sub run {
    my $self = shift;
    my $language = get_var("LANGUAGE");
    my @supported = qw(japanese arabic);
    return unless ($language ~~ @supported);
    # we need to install the check tool
    $self->root_console(tty => 3);
    script_run("loadkeys us");
    # repo setup before using dnf
    repo_setup();
    assert_script_run("dnf -y install fontquery");
    # and give the user tty perms for later
    assert_script_run("chmod 666 /dev/${serialdev}");
    desktop_vt;

    # On the console, the fonts might differ than in GUI.
    # We will perform the tests in the gnome terminal.
    # First, open it!
    desktop_switch_layout 'ascii';
    wait_still_screen(2);

    desktop_launch_terminal;
    # Similarly to _graphical_input.pm, repeat running the command
    # if it fails the first time (it often does).
    unless (check_screen "apps_run_terminal", 30) {
        check_desktop;
        desktop_launch_terminal;
    }
    assert_screen("apps_run_terminal");
    wait_still_screen(stilltime => 5, similarity_level => 42);

    # Run the test command
    my %codes = ("japanese" => "ja", "arabic" => "ar");
    my $code = $codes{$language};
    my $release = lc(get_var("VERSION"));
    assert_script_run("fontquery-diff -l ${code} ${release}", 300);
}

sub test_flags {
    return {fatal => 0};
}

1;

# vim: set sw=4 et:
