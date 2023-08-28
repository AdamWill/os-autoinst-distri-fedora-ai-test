use base "installedtest";
use strict;
use testapi;
use utils;

# This will test that user can switch between two applications
# using the navigation combo Alt-tab.

sub start_maxed {
    my $app = shift;
    menu_launch_type($app);
    assert_screen ["apps_run_$app", "grant_access"];
    # give access rights if asked
    if (match_has_tag "grant_access") {
        click_lastmatch;
        assert_screen "apps_run_$app";
    }
    wait_still_screen(3);
    wait_screen_change { send_key("super-up"); };
    wait_still_screen(2);
}

sub switch_to_app {
    # This will use Alt-tab to switch to the desired application.
    # Use the name of the application and the direction in which
    # the search should be performed, either forward or backward.
    my ($application, $dir, $fullscreen) = @_;
    # If we want to search backwards, we will hold the shift key.
    if ($dir eq "backward") {
        hold_key("shift");
    }
    # Then we hold the alt key to either form shift-alt or just alt
    # key combo.
    hold_key("alt");
    # We will send tab, until we have arrived at the correct icon
    send_key_until_needlematch("navigation_navibar_$application", "tab", 10);
    # We will release the alt key.
    release_key("alt");
    #
    if ($dir eq "backward") {
        release_key("shift");
    }
    my $needle = $fullscreen ? "navigation_${application}_fullscreen" : "apps_run_${application}";
    assert_screen($needle);
    if ($fullscreen) {
        die "Not fullscreen!" if (check_screen("apps_menu_button"));
    }
}

sub check_hidden {
    # This function checks that the application
    # is no longer fully displayed on the screen,
    # because it has been hidden (minimized).
    my $app = shift;
    # First, let us wait until the screen settles.
    wait_still_screen(3);
    # If the application is still shown, let's die.
    die("The application seems not to have been minimized.") if (check_screen("apps_run_$app"));
}

sub run {
    my $self = shift;

    ### Switch between two applications
    # From the setup script, we should be seeing the editor
    # window.
    # Switch to the other application.
    send_key("alt-tab");
    assert_screen("apps_run_files");

    # Switch back
    send_key("alt-tab");
    assert_screen("apps_run_editor");

    ### Switch between more applications

    # Start more applications.
    start_maxed("clocks");
    start_maxed("calculator");
    start_maxed("terminal");

    ## Going forwards
    # Switch to Calculator using alt-tab
    switch_to_app("calculator", "forward");
    # Switch to Clocks using alt-tab
    switch_to_app("clocks", "forward");

    ## Going backwards
    # Switch to Nautilus using shift-alt-tab
    switch_to_app("files", "backward");
    # Switch to Terminal using shift-alt-tab
    switch_to_app("terminal", "backward");

    ### Switch to and from a full screen application
    # We will make Terminal to full screen
    send_key("f11");

    # Switch to Editor
    switch_to_app("editor", "forward");

    # Switch to Terminal (fullscreen)
    switch_to_app("terminal", "backward", 1);

    # Switch to Editor
    switch_to_app("editor", "forward");

    ### Switch between minimised apps.
    # Minimise Editor
    send_key("super-h");
    # Check that the application has minimised.
    check_hidden("editor");

    # Switch to Clocks
    switch_to_app("clocks", "forward");
    # Minimise Clocks
    send_key("super-h");
    # Check that the application has minimised.
    check_hidden("clocks");

    # Switch to Editor
    switch_to_app("editor", "forward");

    # Switch to Clocks
    switch_to_app("clocks", "forward");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:



