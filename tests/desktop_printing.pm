use base "installedtest";
use strict;
use testapi;
use utils;
use i3;

sub run {
    my $self = shift;
    my $usecups = get_var("USE_CUPS");
    # Prepare the environment for the test.
    #
    # Some actions need a root account, so become root.
    $self->root_console(tty => 3);

    # Create a text file, put content to it to prepare it for later printing.
    script_run "cd /home/test/";
    assert_script_run "echo 'A quick brown fox jumps over a lazy dog.' > testfile.txt";
    # Make the file readable and for everybody.
    script_run "chmod 666 testfile.txt";

    # If the test should be running with CUPS-PDF, we need to install it first.
    if ($usecups) {
        my $pkgs = "cups-pdf";
        # On I3, we also need to install the PDF reader.
        if ($desktop eq "i3") {
            $pkgs = $pkgs . " mupdf";
        }
        # Install the Cups-PDF package to use the Cups-PDF printer
        assert_script_run "dnf -y install $pkgs", 240;
    }

    # Here, we were doing a version logic. This is no longer needed, because
    # we now use a different approach to getting the resulting file name:
    # We will list the directory where the printed file is put and we will
    # take the file name that will be returned. To make it work, the directory
    # must be empty, which it normally is, but to make sure let's delete everything.
    script_run("rm /home/test/Desktop/*");
    # Verification commands need serial console to be writable and readable for
    # normal users, let's make it writable then.
    script_run("chmod 666 /dev/${serialdev}");
    # Check whether the cups-pdf printer is actually present on the system
    # FIXME: If it is missing, add it manually by removing and installing
    # cups-pdf again
    my $cups_pdf_present = script_run('lpstat -t|grep -q -i cups-pdf');
    if ($cups_pdf_present != 0) {
        record_soft_failure 'Cups-PDF printer is not present on the system (rhbz#1984295)';
        assert_script_run "dnf -y remove cups-pdf", 180;
        assert_script_run "dnf -y install cups-pdf", 180;
    }
    # FIXME: log version of cups-pdf and check it for output location
    # this is only necessary as long as the test may run on cups-pdf
    # 3.0.1-11 or lower, as soon as that's not true we can cut it
    my $cpdfver = script_output 'rpm -q cups-pdf --queryformat "%{VERSION}-%{RELEASE}\n"';
    assert_script_run "dnf -y install rpmdevtools", 180;
    my $cpdfvercmp = script_run "rpmdev-vercmp $cpdfver 3.0.1-11.5";
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
    unless ($desktop eq "i3") {
        menu_launch_type($term);
        wait_still_screen(5);
    }
    else {
        launch_terminal;
        # switch to tabbed mode
        send_key(get_i3_modifier() . "-w");  
    }

    # Open the text editor and maximize it.
    wait_screen_change { type_very_safely "$editor /home/test/testfile.txt &\n"; };
    wait_still_screen(stilltime => 2, similarity_level => 45);
    unless ($desktop eq "i3") {
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
            type_safely("/home/test/Documents/output.pdf");
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
        send_key "alt-f4" unless $desktop eq "i3";
    }

    # Open the pdf file and check the print
    if ($desktop eq "i3") {
        launch_terminal;
    } else {
        send_key "alt-f2";
        wait_still_screen(stilltime=>5, similarity_level=>45);
    }
    # output location is different for cups-pdf 3.0.1-12 or later (we
    # checked this above)
    if ($cpdfvercmp eq "12") {
        # older cups-pdf
        type_safely "$viewer /home/$user/Desktop/testfile.pdf\n";
    }
    elsif ($editor eq "mousepad") {
        # mousepad creates relatively weird pdf names, so we use a wildcard here
        type_safely "$viewer /home/$user/" . 'Mousepad*job_1.pdf' . "\n";
    }
    else {
        type_safely "$viewer /home/$user/Desktop/testfile-job_1.pdf\n";
    }

    # Get the name of the printed file. The path location depends
    # on the selected method. We do this on a VT because there's
    # no argument to script_output to make it type slowly, and
    # it often fails typing fast in a desktop terminal
    $self->root_console(tty => 3);
    my $directory = $usecups ? "/home/test/Desktop" : "/home/test/Documents";
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
    type_safely("$viewer $filepath &\n");
    wait_still_screen(stilltime => 3, similarity_level => 45);
    # Resize the window, so that the size of the document fits the bigger space
    # and gets more readable.
    send_key $maximize unless !defined($maximize);
    wait_still_screen(stilltime=>2, similarity_level=>45);
    # make sure we're at the start of the document
    send_key "ctrl-home" if ($desktop eq "kde");
    # Check the printed pdf.
    assert_screen "printing_check_sentence";
}


sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
