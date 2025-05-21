use base "installedtest";
use strict;
use testapi;
use utils;

# This test checks if the keyboard layout has been correctly
# set on the system using the new WebUI.

sub parse_layout_output {
    # Take the text and return a hash with data to compare later.
    my $text = shift;
    my %locales;

    for my $line (split /\n/, $text) {
        # Strip whitespaces
        $line =~ s/^\s+|\s+$//g;
        # Skip empty lines
        #next unless length $line;
        #Only take lines with :
        next unless $line =~ /:/;

        # Unpack the line into two a key and a value.
        my ($key, $val) = $line =~ /^([^:]+):\s*(.*)$/;
        # If the above fails, skip it.
        next unless defined $key;

        #$key =~ s/\s+/ /g;                # Again, strip whitespaces.
        #$key =~ s/^\s+|\s+$//g;

        # Add to the hash
        $locales{$key} = $val;
    }
    # Return the hash reference.
    return \%locales;
}



sub run {
    my $self = shift;

    # Switch to the root console for further checks.
    $self->root_console(tty => 3);
    console_loadkeys_us;

    # Read the locales from the system
    my $output = script_output("localectl status");
    my $status = parse_layout_output($output);

    # Do the locales checking
    # The System Locale should be US English,
    # the keyboard layout should be German (de)
    my $failure = 0;
    if ($status->{"System Locale"} ne "LANG=en_US.UTF-8") {
        record_info("Expected system locale is 'en_US.UTF-8' but we got $status->{'System Locale'} instead.");
        $failure += 1;
    }
    if ($status->{"VC Keymap"} ne "de") {
        record_info("Expected VC keymap is 'de' but we got $status->{'VC Keymap'} instead.");
        $failure += 1;
    }

    if ($status->{"X11 Layout"} ne "de") {
        record_info("Expected X11 layout is 'de' but we got $status->{'X11 Layout'} instead.");
        $failure += 1;
    }

    if ($failure >= 1) {
        die("The locale tests have failed.");
    }

    # If the test would have died above, the console needs to be at US and then it is over,
    # which is fine. However, if we reach this point, we return the console back to "de"
    # and if there is need to switch it to US again, it will be done later.
    script_run("loadkeys de");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
