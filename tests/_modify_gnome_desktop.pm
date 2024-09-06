use base "installedtest";
use strict;
use testapi;
use utils;

# This tests creates a drop-in schema to change the default behaviour of Gnome session.


sub run {
    my $self = shift;
    # Setting variables for better clarity
    my $target_file = "/usr/share/glib-2.0/schemas/99_openqa.gschema.override";
    my $source_file = get_var("GNOME_SCHEMA");    # We know it exists or we would not be here.

    # Switch to the root console to perform operations
    $self->root_console(tty => 3);

    # Download the drop-in file, move it to the selected directory
    # and compile the new schemas.
    assert_script_run("curl --retry-delay 10 --max-time 30 --retry 5 -o /tmp/schema_file $source_file");
    assert_script_run("mv /tmp/schema_file $target_file");
    assert_script_run("glib-compile-schemas /usr/share/glib-2.0/schemas/");

    # Reboot the system.
    enter_cmd("reboot");

    # Wait to boot
    boot_to_login_screen(300);

    # Login to the desktop
    dm_perform_login('gnome', get_var("USER_PASSWORD", "weakpassword"));

    # Verify that we have logged in
    check_desktop(120);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:

