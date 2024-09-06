use base "installedtest";
use strict;
use testapi;
use utils;

# This tests creates a drop-in schema to change the default behaviour of Gnome session.


sub run {
    my $self = shift;
    # Only run this on a Gnome desktop, even if GNOME_SCHEMA variable has sent you here.
    if (get_var("DESKTOP") eq "gnome") {
        # Setting variables for better clarity
        my $target_file = "/usr/share/glib-2.0/schemas/99_openqa.gschema.override";
        my $source_file = get_var("GNOME_SCHEMA");    # We know it exists or we would not be here.

        # Switch to the root console to perform operations
        $self->root_console(tty => 3);

        # Download the drop-in file, move it to the selected directory
        # and compile the new schemas.
        assert_script_run("curl -o /tmp/schema_file $source_file");
        assert_script_run("mv /tmp/schema_file $target_file");
        assert_script_run("glib-compile-schemas /usr/share/glib-2.0/schemas/");

        # Reboot the system.
        enter_cmd("reboot");

        # Wait to boot
        boot_to_login_screen(300);

        # Login to the desktop
        my $password = get_var("USER_PASSWORD", "weakpassword");
        send_key_until_needlematch('graphical_login_input', 'ret', 3, 5);
        assert_screen('graphical_login_input');
        wait_still_screen(stilltime => 5, similarity_level => 38);
        type_very_safely("$password\n");

        # Verify that we have logged in and hit escape to come out
        # of Activity mode. This is important while the follow
        # up tests start with Activities mode off.
        check_desktop(120);
        send_key("esc");
        wait_still_screen(3);
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:

