use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    my $usecups = get_var("USE_CUPS");
    my $desktop = get_var("DESKTOP");
    my $user = get_var("USER_LOGIN", "test");
    my $password = get_var("USER_PASSWORD", "weakpassword");
    # Prepare the environment for the test.
    #
    # Some actions need a root account, so become root.
    $self->root_console(tty => 3);

    # Create a text file, put content to it to prepare it for later printing.
    script_run "cd /home/$user/";
    assert_script_run "echo 'A quick brown fox jumps over a lazy dog.' > testfile.txt";
    # Make the file readable and for everybody.
    script_run "chmod 666 testfile.txt";
    if ($desktop eq "i3") {
        assert_script_run("dnf -y install mupdf", timeout => 120);
    }

    # If the test should be running with CUPS-PDF, we need to install it first.
    if ($usecups) {
        my $pkgs = "cups-pdf";
        # Install the Cups-PDF package to use the Cups-PDF printer
        assert_script_run "dnf -y install $pkgs", 120;
        assert_script_run "systemctl restart cups", 30;
    }

    # Here, we were doing a version logic. This is no longer needed, because
    # we now use a different approach to getting the resulting file name:
    # We will list the directory where the printed file is put and we will
    # take the file name that will be returned. To make it work, the directory
    # must be empty, which it normally is, but to make sure let's delete everything.
    script_run("rm /home/$user/Desktop/*");
    # Verification commands need serial console to be writable and readable for
    # normal users, let's make it writable then.
    script_run("chmod 666 /dev/${serialdev}");
    # Leave the root terminal and switch back to desktop for the rest of the test.
    desktop_vt();

    my $desktop = get_var("DESKTOP");
    # Set up some variables to make the test compatible with different desktops.
    # Defaults are for the Gnome desktop.
    my $editor = "gnome-text-editor";
    my $viewer = "evince";
    my $maximize = "super-up";
    my $term = "terminal";
    if ($desktop eq "kde") {
        $editor = "kwrite";
        $viewer = "okular";
        $maximize = "super-pgup";
        $term = "konsole";
    }
    elsif ($desktop eq "i3") {
        $editor = "mousepad";
        $viewer = "mupdf";
        $maximize = undef;
    }

    # give the desktop a few seconds to settle, we seem to be getting
    # a lot of mis-types in KDE if we do not, as of 2024-02
    wait_still_screen(3);
    # On KDE, try and avoid double-typing issues
    if ($desktop eq "kde") {
        kde_doublek_workaround;
    }
    # Let's open the terminal. We will use it to start the applications
    # as well as to check for the name of the printed file.
    desktop_launch_terminal;
    assert_screen("apps_run_terminal");
    wait_still_screen 3;
    # switch to tabbed mode
    send_key("alt-w") if ($desktop eq "i3");
    # Open the text editor and maximize it.
    wait_screen_change { type_very_safely "$editor /home/$user/testfile.txt &\n"; };
    wait_still_screen(stilltime => 2, similarity_level => 45);
    if (defined($maximize)) {
        wait_screen_change { send_key($maximize); };
        wait_still_screen(stilltime => 2, similarity_level => 45);
    }

    # Print the file using one of the available methods
    send_key "ctrl-p";
    wait_still_screen(stilltime => 5, similarity_level => 45);
    # We will select the printing method
    # In case of KDE, we will need to select the printer first.
    if ($desktop eq "kde") {
        assert_and_click "printing_kde_select_printer";
    }
    if ($usecups) {
        assert_and_click "printing_use_cups_printer";
    }
    else {
        assert_and_click "printing_use_saveas_pdf";
        # For KDE, we need to set the output location.
        if ($desktop eq "kde") {
            assert_and_click "printing_kde_location_line";
            send_key("ctrl-a");
            type_safely("/home/$user/Documents/output.pdf");
        }
    }
    assert_and_click "printing_print";
    # In Rawhide from 2023-11-04 onwards, sometimes g-t-e has
    # already died somehow at this point
    if (check_screen "apps_run_terminal", 10) {
        record_soft_failure "gnome-text-editor died!";
    }
    else {
        # Exit the application
        my $killing_weapon = "alt-f4";
        if ($desktop eq "i3") {
            $killing_weapon = "alt-shift-q";
        }
        send_key($killing_weapon);
    }

    # Get the name of the printed file. The path location depends
    # on the selected method. We do this on a VT because there's
    # no argument to script_output to make it type slowly, and
    # it often fails typing fast in a desktop terminal
    $self->root_console(tty => 3);
    my $directory = $usecups ? "/home/$user/Desktop" : "/home/$user/Documents";
    my $filename = script_output("ls $directory");
    my $filepath = "$directory/$filename";

    # Echo that filename to the terminal for troubleshooting purposes
    diag("The file of the printed out file is located in $filepath");

    # back to the desktop
    desktop_vt();
    wait_still_screen(stilltime => 3, similarity_level => 45);
    # The CLI might be blocked by some application output. Pressing the
    # Enter key will dismiss them and return the CLI to the ready status.
    send_key("ret");
    # Open the pdf file in a Document reader and check that it is correctly printed.
    wait_screen_change { type_safely("$viewer $filepath &\n"); };
    wait_still_screen(stilltime => 3, similarity_level => 45);
    # Maximize the screen and check the printed pdf, giving it a few
    # chances to work
    my $count = 5;
    while ($count) {
        $count -= 1;
        send_key($maximize);
        wait_still_screen(stilltime => 3, similarity_level => 45);
        if ($desktop eq "kde") {
            # ensure we're at the start of the document
            send_key "ctrl-home";
            wait_still_screen(stilltime => 2, similarity_level => 45);
        }
        last if (check_screen("printing_check_sentence", 3));
    }
    assert_screen("printing_check_sentence", 5);
}


sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
