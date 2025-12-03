use base "anacondatest";
use strict;
use testapi;
use anaconda;
use utils;


sub _set_root_password {
    # can also hit a transition animation
    wait_still_screen 2;
    my $root_password = get_var("ROOT_PASSWORD", "weakpassword");
    assert_and_click "anaconda_install_root_password";
    # we have to click 'enable root account' before typing the
    #password
    assert_and_click "anaconda_install_root_password_screen";
    # wait out animation
    wait_still_screen 2;
    desktop_switch_layout("ascii", "anaconda") if (get_var("SWITCHED_LAYOUT"));
    # these screens seems insanely subject to typing errors, so
    # type super safely. This doesn't really slow the test down
    # as we still get done before the install process is complete.
    type_very_safely $root_password;
    wait_screen_change { send_key "tab"; };
    type_very_safely $root_password;
    # Another screen to test identification on
    my $identification = get_var('IDENTIFICATION');
    if ($identification eq 'true') {
        check_top_bar();
        # we don't check version or pre-release because here those
        # texts appear on the banner which makes the needling
        # complex and fragile (banner is different between variants,
        # and has a gradient so for RTL languages the background color
        # differs; pre-release text is also translated)
    }
    assert_and_click "anaconda_spoke_done";
    # exiting this screen can take a while, so check for the hub
    assert_screen "anaconda_main_hub", 60;
}

sub _set_root_password_webui {
    my $root_password = get_var("ROOT_PASSWORD", "weakpassword");
    # hit tab till we can see the button, it may be off screen
    send_key_until_needlematch("anaconda_webui_allow_root", "tab", 3, 3);
    # Click the radio button, then get focus and fill the fields.
    assert_and_click("anaconda_webui_allow_root");
    sleep(1);
    type_very_safely($root_password);
    for (1 .. 2) {
        send_key("tab");
        sleep(1);
    }
    type_very_safely($root_password);
}

sub _do_root_and_user {
    # check whether user and root password creation are suppressed,
    # as they may be. if the 'begin installation' button is present
    # and active, they must be suppressed. we use assert_screen not
    # check_screen just to make it faster
    assert_screen [
        'anaconda_install_user_creation',
        'anaconda_webui_no_local_account',
        'anaconda_webui_begin_installation',
        'anaconda_main_hub_begin_installation'
    ];
    if (match_has_tag('anaconda_webui_begin_installation') || match_has_tag('anaconda_main_hub_begin_installation')) {
        set_var('INSTALLER_NO_ROOT', '1');
        set_var('INSTALL_NO_USER', '1');
    }
    my $nouser = (get_var("USER_LOGIN", '') eq 'false' || get_var("INSTALL_NO_USER"));
    my $noroot = get_var("INSTALLER_NO_ROOT");
    return if ($nouser && $noroot);
    if (get_var("_ANACONDA_WEBUI")) {
        if ($nouser) {
            assert_and_click 'anaconda_webui_no_local_account';
        }
        else {
            webui_create_user();
        }
        _set_root_password_webui() unless ($noroot);
        assert_and_click("anaconda_webui_next");
    }
    else {
        _set_root_password() unless ($noroot);
        # Set user details, unless the test is configured not to create one
        unless ($nouser) {
            # Wait out animation
            wait_still_screen 8;
            anaconda_create_user();
        }
    }
    # Check username (and hence keyboard layout) if non-English
    if (get_var('LANGUAGE')) {
        assert_screen "anaconda_install_user_created";
    }

}

sub run {
    my $self = shift;
    my $webui = get_var("_ANACONDA_WEBUI");
    my $desktop = get_var("DESKTOP");

    # From F31 onwards (after Fedora-Rawhide-20190722.n.1), user and
    # root password spokes are moved to main hub, so we must do those
    # before we run the install.
    _do_root_and_user();
    # Begin installation
    # Sometimes, the 'slide in from the top' animation messes with
    # this - by the time we click the button isn't where it was any
    # more. So wait for screen to stop moving before we click.
    assert_screen ["anaconda_main_hub_begin_installation", "anaconda_webui_begin_installation"], 90;
    wait_still_screen 5;
    assert_and_click ["anaconda_main_hub_begin_installation", "anaconda_webui_begin_installation"];
    if ($webui) {
        click_lastmatch if (check_screen "anaconda_webui_confirm_installation", 10);
    }

    # If we want to test identification we will do it
    # on several places in this procedure, such as
    # on this screen and also on password creation screens
    # etc.
    my $identification = get_var('IDENTIFICATION');
    my $branched = get_var('VERSION');
    if ($identification eq 'true' or ($branched ne "Rawhide" && lc($branched) ne "eln")) {
        check_left_bar() unless ($webui);
        check_prerelease();
        check_version();
    }

    # Wait for install to end. Give Rawhide a bit longer, in case
    # we're on a debug kernel, debug kernel installs are really slow.
    my $timeout = 3000;
    my $version = lc(get_var('VERSION'));
    if ($version eq "rawhide") {
        $timeout = 4200;
    }
    # workstation especially has an unfortunate habit of kicking in
    # the screensaver during install...
    my $interval = 60;
    while ($timeout > 0) {
        die "Error encountered!" if (check_screen "anaconda_error_report");
        # move the mouse a bit
        mouse_set 100, 100;
        # also click, if we're a RDP client, seems just moving mouse
        # isn't enough to defeat blanking
        mouse_click if (get_var("RDP_CLIENT"));
        mouse_hide;
        last if (check_screen "anaconda_install_done", $interval);
        $timeout -= $interval;
    }
    assert_screen "anaconda_install_done";
    # wait for transition to complete so we don't click in the sidebar
    wait_still_screen 3;
    # if this is a live install, let's go ahead and quit the installer
    # in all cases, just to make sure quitting doesn't crash etc.
    if (get_var('LIVE')) {
        # not on Workstation with webUI, as it immediately reboots
        assert_and_click "anaconda_install_done" unless ($webui && $desktop eq "gnome");
    }
    # there are various things we might have to do at a console here
    # before we actually reboot. let's figure them all out first...
    my @actions;
    push(@actions, 'consoletty0') if (get_var("ARCH") eq "aarch64");
    push(@actions, 'abrt') if (get_var("ABRT", '') eq "system");
    push(@actions, 'rootpw') if (get_var("INSTALLER_NO_ROOT"));
    push(@actions, 'usbhalt') if (get_var("USBBOOT"));
    # FIXME: remove plymouth from Server install_default_upload on
    # non-aarch64 to work around RHBZ #1933378
    unless (get_var("ARCH") eq "aarch64") {
        if (get_var("FLAVOR") eq "Server-dvd-iso" && get_var("TEST") eq "install_default_upload") {
            push(@actions, 'noplymouth');
        }
    }
    # memcheck test doesn't need to reboot at all. Rebooting from GUI
    # for lives is unreliable. And if we're already doing something
    # else at a console, we may as well reboot from there too
    push(@actions, 'reboot') if (!get_var("MEMCHECK") && (get_var("LIVE") || @actions));
    # our approach for taking all these actions doesn't work on RDP
    # installs, fortunately we don't need any of them in that case
    # yet, so for now let's just flush the list here if we're RDP
    @actions = () if (get_var("RDP_CLIENT"));
    # If we have no actions, let's just go ahead and reboot now,
    # unless this is memcheck
    unless (@actions) {
        unless (get_var("MEMCHECK")) {
            assert_and_click "anaconda_install_done";
        }
        return undef;
    }
    # OK, if we're here, we got actions, so head to a console. Switch
    # to console after liveinst sometimes takes a while, so 30 secs
    $self->root_console(timeout => 30);
    if (get_var("LIVE") && get_var("LAYOUT") eq "french") {
        console_loadkeys_us;
    }
    # this is something a couple of actions may need to know
    my $mount = "/mnt/sysimage";
    if (get_var("CANNED")) {
        # finding the actual host system root is fun for ostree...
        $mount = "/mnt/sysimage/ostree/deploy/fedora*/deploy/*.?";
    }
    if (grep { $_ eq 'consoletty0' } @actions) {
        # somehow, by this point, localized keyboard layout has been
        # loaded for this tty, so for French and Arabic at least we
        # need to load the 'us' layout again for the next command to
        # be typed correctly
        console_loadkeys_us;
        # https://bugzilla.redhat.com/show_bug.cgi?id=1661288 results
        # in boot messages going to serial console on aarch64, we need
        # them on tty0. We also need 'quiet' so we don't get kernel
        # messages, which screw up some needles. if /etc/default/grub
        # is not there, we're probably using bootupd; let's just edit
        # the BLS entries directly in that case
        if (script_run 'sed -i -e "s,\(GRUB_CMDLINE_LINUX.*\)\",\1 console=tty0 quiet\",g" ' . $mount . '/etc/default/grub') {
            assert_script_run 'sed -i -e "s,\(options .*\),\1 console=tty0 quiet,g" ' . $mount . '/boot/loader/entries/*.conf';
        }
        else {
            # regenerate the bootloader config, only necessary if we
            # edited /etc/default/grub
            assert_script_run 'chroot ' . $mount . ' grub2-mkconfig -o $(readlink -m /etc/grub2.cfg)';
        }
    }
    if (grep { $_ eq 'abrt' } @actions) {
        # Chroot in the newly installed system and switch on ABRT systemwide
        assert_script_run "chroot $mount abrt-auto-reporting 1";
    }
    if (grep { $_ eq 'rootpw' } @actions) {
        my $root_password = get_var("ROOT_PASSWORD") || "weakpassword";
        # this seems to have started to fail periodically with "failure while
        # writing changes to /etc/shadow" on 2023-09-01, attempt to work
        # around that
        my $count = 5;
        while ($count) {
            last unless (script_run "echo 'root:$root_password' | chpasswd -R $mount");
            die "setting root password failed five time!" unless ($count);
            $count -= 1;
        }
        # fix SELinux context on /etc/shadow to avoid denials later
        script_run "chroot $mount restorecon -v /etc/shadow";
    }
    if (grep { $_ eq 'noplymouth' } @actions) {
        assert_script_run "chroot $mount dnf -y remove plymouth";
    }
    if (grep { $_ eq 'usbhalt' } @actions) {
        # halt the system cleanly to ensure install is complete
        type_string "systemctl halt\n";
        wait_still_screen 5;
        # disconnect the USB stick
        disconnect_usb;
        # reboot via ACPI
        power "reset";
        return;
    }
    type_string "reboot\n" if (grep { $_ eq 'reboot' } @actions);
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
