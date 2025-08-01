use base "installedtest";
use strict;
use testapi;
use anaconda;
use utils;

sub _enter_password {
    my $password = shift;
    if (get_var("SWITCHED_LAYOUT")) {
        # see _do_install_and_reboot; when layout is switched
        # user password is doubled to contain both US and native
        # chars
        desktop_switch_layout 'ascii';
        type_very_safely $password;
        desktop_switch_layout 'native';
        type_very_safely $password;
    }
    else {
        type_very_safely $password;
    }
    send_key "ret";
}

sub run {
    my $self = shift;
    my $password = get_var("USER_PASSWORD", "weakpassword");
    my $version = get_var("VERSION");
    my $desktop = get_var("DESKTOP");
    # If KICKSTART is set, then the wait_time needs to consider the
    # install time. if UPGRADE, we have to wait for the entire upgrade
    # unless ENCRYPT_PASSWORD is set (in which case the postinstall
    # test does the waiting)
    my $wait_time = 300;
    $wait_time = 1800 if (get_var("KICKSTART"));
    $wait_time = 6000 if (get_var("UPGRADE") && !get_var("ENCRYPT_PASSWORD"));

    # handle bootloader, if requested
    if (get_var("GRUB_POSTINSTALL")) {
        do_bootloader(postinstall => 1, params => get_var("GRUB_POSTINSTALL"), timeout => $wait_time);
        $wait_time = 300;
    }

    # Handle pre-login initial setup if we're doing INSTALL_NO_USER
    if (get_var("INSTALL_NO_USER") && !get_var("_SETUP_DONE")) {
        if ($desktop eq 'gnome') {
            gnome_initial_setup(prelogin => 1, timeout => $wait_time);
        }
        else {
            anaconda_create_user(timeout => $wait_time);
            # wait out animation
            wait_still_screen 3;
            assert_and_click "initialsetup_finish_configuration";
            set_var("_SETUP_DONE", 1);
        }
        $wait_time = 300;
    }
    # Wait for the login screen, unless we're doing a GNOME no user
    # install, which transitions straight from g-i-s to logged-in
    # desktop
    unless ($desktop eq 'gnome' && get_var("INSTALL_NO_USER")) {
        boot_to_login_screen(timeout => $wait_time);
        # if USER_LOGIN is set to string 'false', we're done here
        return if (get_var("USER_LOGIN") eq "false");

        # GDM 3.24.1 dumps a cursor in the middle of the screen here...
        mouse_hide;
        if ($desktop eq 'gnome') {
            # we have to hit enter to get the password dialog, and it
            # doesn't always work for some reason so just try it three
            # times
            send_key_until_needlematch("graphical_login_input", "ret", 3, 5);
        }
        assert_screen "graphical_login_input";
        # seems like we often double-type on aarch64 if we start right
        # away
        wait_still_screen(stilltime => 5, similarity_level => 38);
        _enter_password($password);
    }

    # Handle the welcome tour, unless _WELCOME_DONE is set (indicating
    # it's been done previously within this test run, e.g. the second
    # time this module runs on the update flow, or earlier in the boot
    # process on the INSTALL_NO_USER flow), or START_AFTER_TEST is set
    # to the same value as DEPLOY_UPLOAD_TEST (in which case it will
    # have been done by the previous test run).
    # the point of the default values here is to make the check fail if
    # neither var is set, without needing an extra condition
    my $sat = get_var("START_AFTER_TEST", "1");
    my $dut = get_var("DEPLOY_UPLOAD_TEST", "2");
    handle_welcome_screen if ($sat ne $dut && !get_var("_WELCOME_DONE"));
    if (get_var("IMAGE_DEPLOY")) {
        # if this was an image deployment, we also need to create
        # root user now, for subsequent tests to work
        select_console "tty3-console";
        console_login(user => get_var("USER_LOGIN", "test"), password => get_var("USER_PASSWORD", "weakpassword"));
        wait_still_screen 3;
        type_string "sudo su\n";
        wait_still_screen 3;
        type_string "$password\n";
        wait_still_screen 3;
        my $root_password = get_var("ROOT_PASSWORD") || "weakpassword";
        assert_script_run "echo 'root:$root_password' | chpasswd";
        desktop_vt;
    }

    # Move the mouse somewhere it won't highlight the match areas and
    # hopefully won't negatively interact with anything else later
    mouse_set(1023, 384);
    # KDE can take ages to start up
    check_desktop(timeout => 120);
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
