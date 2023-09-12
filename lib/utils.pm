package utils;

use strict;

use base 'Exporter';
use Exporter;

use lockapi;
use testapi;
our @EXPORT = qw/run_with_error_check type_safely type_very_safely desktop_vt boot_to_login_screen console_login console_switch_layout desktop_switch_layout console_loadkeys_us do_bootloader boot_decrypt check_release menu_launch_type repo_setup setup_workaround_repo disable_updates_repos mount_update_image umount_update_image cleanup_workaround_repo console_initial_setup handle_welcome_screen gnome_initial_setup anaconda_create_user check_desktop download_modularity_tests quit_firefox advisory_get_installed_packages advisory_check_nonmatching_packages start_with_launcher quit_with_shortcut disable_firefox_studies select_rescue_mode copy_devcdrom_as_isofile get_release_number check_left_bar check_top_bar check_prerelease check_version spell_version_number _assert_and_click is_branched rec_log repos_mirrorlist register_application get_registered_applications solidify_wallpaper check_and_install_git download_testdata make_serial_writable/;

# We introduce this global variable to hold the list of applications that have
# registered during the apps_startstop_test when they have sucessfully run.
our @application_list;

sub run_with_error_check {
    my ($func, $error_screen) = @_;
    # Check screen does not work for serial console, so we need to use
    # different checking mechanism for it.
    if (testapi::is_serial_terminal) {
        # by using 'unless' and 'expect_not_found=>1' here we avoid
        # the web UI showing each failure to see the error message as
        # a 'failed match'
        die "Error screen appeared" unless (wait_serial($error_screen, timeout => 5, expect_not_found => 1));
        $func->();
        die "Error screen appeared" unless (wait_serial($error_screen, timeout => 5, expect_not_found => 1));
    }
    else {
        die "Error screen appeared" if (check_screen $error_screen, 5);
        $func->();
        die "Error screen appeared" if (check_screen $error_screen, 5);
    }
}

# high-level 'type this string quite safely but reasonably fast'
# function whose specific implementation may vary
sub type_safely {
    my $string = shift;
    type_string($string, wait_screen_change => 3, max_interval => 20);
    # similarity level 38 as there will commonly be a flashing
    # cursor and the default level (47) is too tight
    wait_still_screen(stilltime => 2, similarity_level => 38);
}

# high-level 'type this string extremely safely and rather slow'
# function whose specific implementation may vary
sub type_very_safely {
    my $string = shift;
    type_string($string, wait_screen_change => 1, max_interval => 1);
    # similarity level 38 as there will commonly be a flashing
    # cursor and the default level (47) is too tight
    wait_still_screen(stilltime => 5, similarity_level => 38);
}

sub get_release_number {
    # return the release number; so usually VERSION, but for Rawhide,
    # we return RAWREL. This allows us to avoid constantly doing stuff
    # like `if ($version eq "Rawhide" || $version > 30)`.
    my $version = get_var("VERSION");
    my $rawrel = get_var("RAWREL", "Rawhide");
    return $rawrel if ($version eq "Rawhide");
    return $version;
}

# Wait for login screen to appear. Handle the annoying GPU buffer
# problem where we see a stale copy of the login screen from the
# previous boot. Will suffer a ~30 second delay if there's a chance
# we're *already at* the expected login screen.
sub boot_to_login_screen {
    my %args = @_;
    $args{timeout} //= 300;
    if (testapi::is_serial_terminal) {
        # For serial console, just wait for the login prompt
        unless (wait_serial "login:", timeout => $args{timeout}) {
            die "No login prompt shown on serial console.";
        }
    }
    else {
        # we may start at a screen that matches one of the needles; if so,
        # wait till we don't (e.g. when rebooting at end of live install,
        # we match text_console_login until the console disappears).
        # The following is true for non-serial console.
        my $count = 5;
        while (check_screen("login_screen", 3) && $count > 0) {
            sleep 5;
            $count -= 1;
        }
        assert_screen "login_screen", $args{timeout};
        if (match_has_tag "graphical_login") {
            wait_still_screen(timeout => 30, stilltime => 10, similarity_level => 38);
            assert_screen "login_screen";
        }
    }
}

# Switch keyboard layouts at a console
sub console_switch_layout {
    # switcher key combo differs between layouts, for console
    if (get_var("LANGUAGE", "") eq "russian") {
        send_key "ctrl-shift";
    }
}

# switch to 'native' or 'ascii' input method in a graphical desktop
# usually switched configs have one mode for inputting ascii-ish
# characters (which may be 'us' keyboard layout, or a local layout for
# inputting ascii like 'jp') and one mode for inputting native
# characters (which may be another keyboard layout, like 'ru', or an
# input method for more complex languages)
# 'environment' can be a desktop name or 'anaconda' for anaconda
# if not set, will use get_var('DESKTOP') or default 'anaconda'
sub desktop_switch_layout {
    my ($layout, $environment) = @_;
    $layout //= 'ascii';
    $environment //= get_var("DESKTOP", "anaconda");
    # if already selected, we're good
    return if (check_screen "${environment}_layout_${layout}", 3);
    # otherwise we need to switch
    my $switcher = "alt-shift";    # anaconda
    $switcher = "super-spc" if $environment eq 'gnome';
    # KDE? not used yet
    # FIXME we use send_key_until_needlematch because sometimes the
    # switch just doesn't work in gdm:
    # https://gitlab.gnome.org/GNOME/gnome-shell/-/issues/6066#note_1707051
    send_key_until_needlematch("${environment}_layout_${layout}", $switcher, 3, 3);
}

# this is used at the end of console_login to check if we got a prompt
# indicating that we got a bash shell, but sourcing of /etc/bashrc
# failed (the prompt looks different in this case). We treat this as
# a soft failure.
sub _console_login_finish {
    # The check differs according to the console used.
    if (testapi::is_serial_terminal) {
        unless (wait_serial("-bash-.*[#\$]", timeout => 5, expect_not_found => 1)) {
            record_soft_failure "It looks like profile sourcing failed";
        }
    }
    else {
        if (match_has_tag "bash_noprofile") {
            record_soft_failure "It looks like profile sourcing failed";
        }
    }
}

# this subroutine handles logging in as a root/specified user into console
# it requires TTY to be already displayed (handled by the root_console()
# method of distribution classes)
sub console_login {
    my %args = (
        user => "root",
        password => get_var("ROOT_PASSWORD", "weakpassword"),
        # default is 10 seconds, set below, 0 means 'default'
        timeout => 0,
        @_
    );
    $args{timeout} ||= 10;

    # Since we do not test many serial console tests, and we probably
    # only want to test serial console on a minimal installation only,
    # let us not do all the magic to handle different console logins
    # and let us simplify the process.
    # We will check if we are logged in, and if so, we will log out to
    # enable a new proper login based on the user variable.
    if (get_var("SERIAL_CONSOLE")) {
        # Check for the usual prompt.
        if (wait_serial("~\][#\$]", timeout => 5, quiet => 1)) {
            type_string "logout\n";
            # Wait a bit to let the logout properly finish.
            sleep 10;
        }
        # Do the new login.
        type_string $args{user};
        type_string "\n";
        sleep 2;
        type_string $args{password};
        type_string "\n";
        # Let's perform a simple login test. This is the same as
        # whoami, but has the advantage of existing in installer env
        assert_script_run "id -un";
        unless (wait_serial $args{user}, timeout => 5) {
            die "Logging onto the serial console has failed.";
        }
    }
    else {
        # There's a timing problem when we switch from a logged-in console
        # to a non-logged in console and immediately call this function;
        # if the switch lags a bit, this function will match one of the
        # logged-in needles for the console we switched from, and get out
        # of sync (e.g. https://openqa.stg.fedoraproject.org/tests/1664 )
        # To avoid this, we'll sleep a few seconds before starting
        sleep 4;

        my $good = "";
        my $bad = "";
        if ($args{user} eq "root") {
            $good = "root_console";
            $bad = "user_console";
        }
        else {
            $good = "user_console";
            $bad = "root_console";
        }

        if (check_screen $bad, 0) {
            # we don't want to 'wait' for this as it won't return
            my $script = "exit";
            # If Turkish keyboard is installed, the word "exit" is typed
            # incorrectly because the keyboard layout is different and
            # openQA sends keys according to the English layout.
            # Therefore we need to send a string that is
            # correctly interpreted by the Turkish layout.
            if (get_var("LANGUAGE") eq "turkish") {
                $script = "ex't";
            }
            script_run $script, 0;
            sleep 2;
        }

        assert_screen [$good, 'text_console_login'], $args{timeout};
        # if we're already logged in, all is good
        if (match_has_tag $good) {
            _console_login_finish();
            return;
        }
        # otherwise, we saw the login prompt, type the username
        type_string("$args{user}\n");
        assert_screen [$good, 'console_password_required'], 45;
        # on a live image, just the user name will be enough
        if (match_has_tag $good) {
            # clear the screen (so the remaining login prompt text
            # doesn't confuse subsequent runs of this)
            my $clearstr = "clear\n";
            $clearstr = "cleqr\n" if (get_var("LANGUAGE") eq 'french');
            type_string $clearstr;
            _console_login_finish();
            return;
        }
        # otherwise, type the password
        type_string "$args{password}";
        if (get_var("SWITCHED_LAYOUT") and $args{user} ne "root") {
            # see _do_install_and_reboot; when layout is switched
            # user password is doubled to contain both US and native
            # chars
            console_switch_layout;
            type_string "$args{password}";
            console_switch_layout;
        }
        send_key "ret";
        # make sure we reached the console
        unless (check_screen($good, 30)) {
            # as of 2018-10 we have a bug in sssd which makes this take
            # unusually long in the FreeIPA tests, let's allow longer,
            # with a soft fail - RHBZ #1644919
            record_soft_failure "Console login is taking a long time - #1644919?";
            my $timeout = 30;
            # even an extra 30 secs isn't long enough on aarch64...
            $timeout = 90 if (get_var("ARCH") eq "aarch64");
            assert_screen($good, $timeout);
        }
        # clear the screen (so the remaining login prompt text
        # doesn't confuse subsequent runs of this)
        my $clearstr = "clear\n";
        $clearstr = "cleqr\n" if (get_var("LANGUAGE") eq 'french');
        type_string $clearstr;
    }
    _console_login_finish();
}

# Figure out what tty the desktop is on, switch to it. Assumes we're
# at a root console
sub desktop_vt {
    # use loginctl or ps to find the tty of test's session (loginctl)
    # or gnome-session, Xwayland or Xorg (ps); as of 2019-09 we often
    # get tty? for Xwayland and Xorg processes, so using loginctl can
    # help
    my $xout;
    # don't fail test if we don't find any process, just guess tty1.
    # os-autoinst calls the script with 'bash -e' which causes it to
    # stop as soon as any command fails, so we use ||: to make the
    # first grep return 0 even if it matches nothing
    eval { $xout = script_output ' loginctl | grep test ||:; ps -e | egrep "(startplasma|gnome-session|Xwayland|Xorg)" | grep -o tty[0-9] ||:' };
    my $tty = 1;    # default
    while ($xout =~ /tty(\d)/g) {
        $tty = $1;    # most recent match is probably best
    }
    send_key "ctrl-alt-f${tty}";
    # work around https://gitlab.gnome.org/GNOME/gnome-software/issues/582
    # if it happens. As of 2019-05, seeing something similar on KDE too
    my $desktop = get_var('DESKTOP');
    my $sfr = 0;
    my $timeout = 10;
    my $count = 6;
    while (check_screen("auth_required", $timeout) && $count > 0) {
        $count -= 1;
        unless ($sfr) {
            record_soft_failure "spurious 'auth required' - https://gitlab.gnome.org/GNOME/gnome-software/issues/582";
            $sfr = 1;
            $timeout = 3;
        }
        click_lastmatch if ($desktop eq 'kde');
        if (match_has_tag "auth_required_fprint") {
            my $user = get_var("USER_LOGIN", "test");
            send_key "ctrl-alt-f6";
            console_login;
            assert_script_run "echo SCAN ${user}-finger-1 | socat STDIN UNIX-CONNECT:/run/fprintd-virt";
            send_key "ctrl-alt-f${tty}";
        }
        else {
            # bit sloppy but in all cases where this is used, this is the
            # correct password
            type_very_safely "weakpassword\n";
        }
    }
}

# load US layout (from a root console)
sub console_loadkeys_us {
    if (get_var('LANGUAGE') eq 'french') {
        script_run "loqdkeys us", 0;
        # might take a few secs
        sleep 3;
    }
    elsif (get_var('LANGUAGE') eq 'japanese' || get_var('LANGUAGE') eq 'turkish') {
        script_run "loadkeys us", 0;
        sleep 3;
    }
}

sub do_bootloader {
    # Handle bootloader screen.
    # 'uefi' is whether this is a UEFI install, will get_var UEFI if
    # not explicitly set. 'postinstall' is whether we're on an
    # installed system or at the installer (this matters for how many
    # times we press 'down' to find the kernel line when typing args).
    # 'args' is a string of extra kernel args, if desired. 'mutex' is
    # a parallel test mutex lock to wait for before proceeding, if
    # desired. 'first' is whether to hit 'up' a couple of times to
    # make sure we boot the first menu entry. 'timeout' is how long to
    # wait for the bootloader screen.
    my %args = (
        postinstall => 0,
        params => "",
        mutex => "",
        first => 1,
        timeout => 30,
        uefi => get_var("UEFI"),
        ofw => get_var("OFW"),
        @_
    );
    my $relnum = get_release_number;
    # we use the firmware-type specific tags because we want to be
    # sure we actually did a UEFI boot
    my $boottag = "bootloader_bios";
    $boottag = "bootloader_uefi" if ($args{uefi});
    assert_screen $boottag, $args{timeout};
    if ($args{mutex}) {
        # cancel countdown
        send_key "left";
        mutex_lock $args{mutex};
        mutex_unlock $args{mutex};
    }
    if ($args{first}) {
        # press up a couple of times to make sure we're at first entry
        send_key "up";
        send_key "up";
    }
    if ($args{params}) {
        send_key "e";
        # we need to get to the 'linux' line here, and grub does
        # not have any easy way to do that. Depending on the arch
        # and the Fedora release, we may have to press 'down' 2
        # times, or 13, or 12, or some other goddamn number. That
        # got painful to keep track of, so let's go bottom-up:
        # press 'down' 50 times to make sure we're at the bottom,
        # then 'up' twice to reach the 'linux' line. This seems to
        # work in every permutation I can think of to test.
        for (1 .. 50) {
            send_key 'down';
        }
        sleep 1;
        send_key 'up';
        sleep 1;
        send_key 'up';
        send_key "end";
        # Change type_string by type_safely because keyboard polling
        # in SLOF usb-xhci driver failed sometimes in powerpc
        type_safely " $args{params}";
    }
    # for debug purpose
    save_screenshot;
    # ctrl-X boots from grub editor mode
    send_key "ctrl-x";
    # return boots all other cases
    send_key "ret";
}

sub boot_decrypt {
    # decrypt storage during boot; arg is timeout (in seconds)
    my $timeout = shift || 60;
    assert_screen "boot_enter_passphrase", $timeout;
    type_string get_var("ENCRYPT_PASSWORD");
    send_key "ret";
}

sub check_release {
    # Checks whether the installed release matches a given value. E.g.
    # `check_release(23)` checks whether the installed system is
    # Fedora 23. The value can be 'Rawhide' or a Fedora release
    # number; often you will want to use `get_var('VERSION')`. Expects
    # a console prompt to be active when it is called.
    my $release = shift;
    my $check_command = "grep SUPPORT_PRODUCT_VERSION /etc/os-release";
    validate_script_output $check_command, sub { $_ =~ m/REDHAT_SUPPORT_PRODUCT_VERSION=$release/ };
}

sub disable_firefox_studies {
    if (get_var("CANNED")) {
        # enable rpm-ostree /usr overlay so we can write to /usr
        assert_script_run "rpm-ostree usroverlay";
    }
    # if the first file exists, we've already run, so we can skip
    # running again
    return unless (script_run 'test -f $(rpm --eval %_libdir)/firefox/distribution/policies.json');
    # create a config file that disables Firefox's dumb 'shield
    # studies' so they don't break tests:
    # https://bugzilla.mozilla.org/show_bug.cgi?id=1529626
    # and also disables the password manager stuff so that doesn't
    # break password entry:
    # https://bugzilla.mozilla.org/show_bug.cgi?id=1635833
    # and *also* tries to disable "first run pages", though this
    # doesn't seem to be working yet:
    # https://bugzilla.mozilla.org/show_bug.cgi?id=1703903
    assert_script_run 'mkdir -p $(rpm --eval %_libdir)/firefox/distribution';
    assert_script_run 'printf \'{"policies": {"DisableFirefoxStudies": true, "OfferToSaveLogins": false, "OverrideFirstRunPage": "", "OverridePostUpdatePage": ""}}\' > $(rpm --eval %_libdir)/firefox/distribution/policies.json';
    # Now create a preferences override file that disables the
    # quicksuggest and total cookie protection onboarding screens
    # see https://support.mozilla.org/en-US/kb/customizing-firefox-using-autoconfig
    # for why this wacky pair of files with required values is needed
    # and https://bugzilla.mozilla.org/show_bug.cgi?id=1703903 again
    # for the actual values
    assert_script_run 'mkdir -p $(rpm --eval %_libdir)/firefox/browser/defaults/preferences';
    assert_script_run 'printf "// required comment\npref(\'general.config.filename\', \'openqa-overrides.cfg\');\npref(\'general.config.obscure_value\', 0);\n" > $(rpm --eval %_libdir)/firefox/browser/defaults/preferences/openqa-overrides.js';
    assert_script_run 'printf "// required comment\npref(\'browser.urlbar.quicksuggest.shouldShowOnboardingDialog\', false);\npref(\'privacy.restrict3rdpartystorage.rollout.enabledByDefault\', false);\n" > $(rpm --eval %_libdir)/firefox/openqa-overrides.cfg';
}

sub repos_mirrorlist {
    # Use mirrorlist not metalink so we don't hit the timing issue where
    # the infra repo is updated but mirrormanager metadata checksums
    # have not been updated, and the infra repo is rejected as its
    # metadata checksum isn't known to MM
    my $files = shift;
    $files ||= "/etc/yum.repos.d/fedora*.repo";
    assert_script_run "sed -i -e 's,metalink,mirrorlist,g' ${files}";
}

sub mount_update_image {
    # mount the update and workarounds images (whichever are attached)
    if (get_var("ISO_2") && script_run "grep updateiso /proc/mounts") {
        script_run "mkdir -p /mnt/updateiso";
        my $devnode = "/dev/sr0";
        $devnode = "/dev/sr1" if (get_var("ISO") || get_var("ISO_1"));
        assert_script_run 'echo "' . $devnode . ' /mnt/updateiso iso9660 loop 0 0" >> /etc/fstab';
        assert_script_run "mount /mnt/updateiso";
    }
    if (get_var("ISO_3") && script_run "grep workaroundsiso /proc/mounts") {
        script_run "mkdir -p /mnt/workaroundsiso";
        my $devnum = 0;
        $devnum++ if (get_var("ISO") || get_var("ISO_1"));
        $devnum++ if (get_var("ISO_2"));
        my $devnode = "/dev/sr${devnum}";
        assert_script_run 'echo "' . $devnode . ' /mnt/workaroundsiso iso9660 loop 0 0" >> /etc/fstab';
        assert_script_run "mount /mnt/workaroundsiso";
    }
}

sub umount_update_image {
    # inverse of mount_update_image
    assert_script_run "sed -i '/updateiso/d' /etc/fstab" if (get_var("ISO_2"));
    assert_script_run "sed -i '/workaroundsiso/d' /etc/fstab" if (get_var("ISO_3"));
    assert_script_run "umount /mnt/updateiso" unless (!get_var("ISO_2") || script_run "grep updateiso /proc/mounts");
    assert_script_run "umount /mnt/workaroundsiso" unless (!get_var("ISO_3") || script_run "grep workaroundsiso /proc/mounts");
}

sub cleanup_workaround_repo {
    # clean up the workaround repo (see next).
    script_run "rm -f /etc/yum.repos.d/workarounds.repo";
}

sub setup_workaround_repo {
    # we periodically need to pull an update from updates-testing in
    # to fix some bug or other. so, here's an organized way to do it.
    # the code that builds the image, and the workaround lists, are
    # in fedora_openqa schedule.py. If there are no workarounds, we
    # don't get an ISO
    return unless (get_var("ISO_3"));
    my $version = shift || get_var("VERSION");
    cleanup_workaround_repo;
    mount_update_image;
    # write a repo config file, unless this is the support_server test
    # and it is running on a different release than the update is for
    # (in this case we need the repo to exist but do not want to use
    # it on the actual support_server system)
    unless (get_var("TEST") eq "support_server" && $version ne get_var("CURRREL")) {
        assert_script_run 'printf "[workarounds]\nname=Workarounds repo\nbaseurl=file:///mnt/workaroundsiso/workarounds_repo\nenabled=1\nmetadata_expire=1\ngpgcheck=0" > /etc/yum.repos.d/workarounds.repo';
    }
}

sub disable_updates_repos {
    # disable updates-testing, or both updates-testing and updates.
    # factors out similar code in a few different places.
    my %args = (
        both => 0,
        @_
    );
    # FIXME as of 2023-06-20 dnf5 doesn't have config-manager plugin yet :(
    assert_script_run 'sed -i -e "s,enabled=1,enabled=0,g" /etc/yum.repos.d/fedora-updates-testing.repo';
    assert_script_run 'sed -i -e "s,enabled=1,enabled=0,g" /etc/yum.repos.d/fedora-updates.repo' if ($args{both});
    unless (script_run 'test -f /etc/yum.repos.d/fedora-updates-testing-modular.repo') {
        assert_script_run 'sed -i -e "s,enabled=1,enabled=0,g" /etc/yum.repos.d/fedora-updates-testing-modular.repo';
        assert_script_run 'sed -i -e "s,enabled=1,enabled=0,g" /etc/yum.repos.d/fedora-updates-modular.repo' if ($args{both});
    }
}

sub _repo_setup_compose {
    # doesn't work for IoT or CoreOS, anything that hits this on those
    # paths must work with default mirror config...
    my $subvariant = get_var("SUBVARIANT");
    return if ($subvariant eq "IoT" || $subvariant eq "CoreOS");
    # Appropriate repo setup steps for testing a compose
    # disable updates-testing and updates and use the compose location
    # as the target for fedora and rawhide rather than mirrorlist, so
    # tools see only packages from the compose under test
    my $location = get_var("LOCATION");
    return unless $location;
    disable_updates_repos(both => 1);
    # we use script_run here as the rawhide and modular repo files
    # won't always exist and we don't want to bother testing or
    # predicting their existence; assert_script_run doesn't buy you
    # much with sed as it'll return 0 even if it replaced nothing
    script_run "sed -i -e 's,^metalink,#metalink,g' -e 's,^mirrorlist,#mirrorlist,g' -e 's,^#baseurl.*basearch,baseurl=${location}/Everything/\$basearch,g' -e 's,^#baseurl.*source,baseurl=${location}/Everything/source,g' /etc/yum.repos.d/{fedora,fedora-rawhide}.repo", 0;
    script_run "sed -i -e 's,^metalink,#metalink,g' -e 's,^mirrorlist,#mirrorlist,g' -e 's,^#baseurl.*basearch,baseurl=${location}/Modular/\$basearch,g' -e 's,^#baseurl.*source,baseurl=${location}/Modular/source,g' /etc/yum.repos.d/{fedora-modular,fedora-rawhide-modular}.repo", 0;

    # this can be used for debugging if something is going wrong
    # unless (script_run 'pushd /etc/yum.repos.d && tar czvf yumreposd.tar.gz * && popd') {
    #     upload_logs "/etc/yum.repos.d/yumreposd.tar.gz";
    # }
}

sub _repo_setup_updates {
    # Appropriate repo setup steps for testing a Bodhi update
    # sanity check
    die "_repo_setup_updates called, but ISO_2 is not attached!" unless (get_var("ISO_2") || get_var("TAG"));
    mount_update_image if (get_var("ISO_2"));
    # Check if we already ran, bail if so
    return unless script_run "test -f /root/.oqarsurun";
    my $version = get_var("VERSION");
    my $currrel = get_var("CURRREL", "0");
    my $arch = get_var("ARCH");
    my $tag = get_var("TAG");
    # this can be used for debugging repo config if something is wrong
    # unless (script_run 'pushd /etc/yum.repos.d && tar czvf yumreposd.tar.gz * && popd') {
    #     upload_logs "/etc/yum.repos.d/yumreposd.tar.gz";
    # }

    # Set up an additional repo containing the update or task packages. We do
    # this rather than simply running a one-time update because it may be the
    # case that a package from the update isn't installed *now* but will be
    # installed by one of the tests; by setting up a repo containing the
    # update and enabling it here, we ensure all later 'dnf install' calls
    # will get the packages from the update.
    # on CANNED, we need to enter the toolbox at this point
    if (get_var("CANNED")) {
        type_string "toolbox -y enter\n";
        # look for the little purple dot
        assert_screen "console_in_toolbox", 180;
    }
    # use mirrorlist not metalink in repo configs
    repos_mirrorlist();
    # Disable updates-testing so other bad updates don't break us
    disable_updates_repos(both => 0) if ($version > $currrel);
    # use the buildroot repo on Rawhide: see e.g.
    # https://pagure.io/fedora-ci/general/issue/376 for why
    if ($version eq get_var("RAWREL") && get_var("TEST") ne "support_server") {
        assert_script_run 'printf "[koji-rawhide]\nname=koji-rawhide\nbaseurl=https://kojipkgs.fedoraproject.org/repos/f' . $version . '-build/latest/' . $arch . '/\ncost=2000\nenabled=1\nmetadata_expire=30\ngpgcheck=0\nskip_if_unavailable=1\n" > /etc/yum.repos.d/koji-rawhide.repo';
    }
    # set up the workaround repo
    setup_workaround_repo;
    upload_logs "/mnt/updateiso/updatepkgnames.txt" unless ($tag);
    upload_logs "/mnt/updateiso/updatepkgs.txt" unless ($tag);
    # write a repo config file, unless this is the support_server test
    # and it is running on a different release than the update is for
    # (in this case we need the repo to exist but do not want to use
    # it on the actual support_server system)
    unless (get_var("TEST") eq "support_server" && $version ne get_var("CURRREL")) {
        if ($tag) {
            assert_script_run 'printf "[openqa-testtag]\nname=openqa-testtag\nbaseurl=https://kojipkgs.fedoraproject.org/repos/' . "$tag/latest/$arch" . '/\ncost=2000\nenabled=1\ngpgcheck=0\n" > /etc/yum.repos.d/openqa-testtag.repo';
        }
        else {
            assert_script_run 'printf "[advisory]\nname=Advisory repo\nbaseurl=file:///mnt/updateiso/update_repo\nenabled=1\nmetadata_expire=3600\ngpgcheck=0" > /etc/yum.repos.d/advisory.repo';
        }
        # run an update now, except for upgrade or install tests,
        # where the updated packages should have been installed
        # already and we want to fail if they weren't, or CANNED
        # tests, there's no point updating the toolbox
        script_run "dnf -y update", 1200 unless (get_var("UPGRADE") || get_var("INSTALL") || get_var("CANNED"));
        # work around update removing 'dnf' command for the dnf5
        # revert: https://bodhi.fedoraproject.org/updates/FEDORA-2023-5fd964c1bf#comment-3149533
        if (get_var("ADVISORY_OR_TASK") eq "FEDORA-2023-5fd964c1bf") {
            script_run "dnf5 -y --best install 'dnf < 5'", 300 unless (get_var("UPGRADE") || get_var("INSTALL") || get_var("CANNED"));
        }
        # on liveinst tests, we'll remove the packages we installed
        # above (and their deps, which dnf will include automatically),
        # just in case they're in the update under test; otherwise we
        # get a bogus failure for the package not being updated
        script_run "dnf -y remove bodhi-client createrepo koji", 600 if (get_var("INSTALL") && !get_var("CANNED"));
    }
    # exit the toolbox on CANNED
    if (get_var("CANNED")) {
        type_string "exit\n";
        wait_still_screen 5;
    }
    assert_script_run "touch /root/.oqarsurun";
}

sub repo_setup {
    # Run the appropriate sub-function for the job
    get_var("ADVISORY_OR_TASK") ? _repo_setup_updates : _repo_setup_compose;
    # This repo does not always exist for Rawhide or Branched, and
    # some things (at least realmd) try to update the repodata for
    # it even though it is disabled, and fail. At present none of the
    # tests needs it, so let's just unconditionally nuke it.
    assert_script_run "rm -f /etc/yum.repos.d/fedora-cisco-openh264.repo";
}

sub console_initial_setup {
    # Handle console initial-setup. Currently used only for ARM disk
    # image tests.
    assert_screen "console_initial_setup", 500;
    # IMHO it's better to use sleeps than to have needle for every text screen
    wait_still_screen 5;

    # Set timezone
    type_string "2\n";
    wait_still_screen 5;
    type_string "1\n";    # Set timezone
    wait_still_screen 5;
    type_string "1\n";    # Europe
    wait_still_screen 5;
    type_string "37\n";    # Prague
    wait_still_screen 7;

    # Set root password
    type_string "4\n";
    wait_still_screen 5;
    type_string get_var("ROOT_PASSWORD") || "weakpassword";
    send_key "ret";
    wait_still_screen 5;
    type_string get_var("ROOT_PASSWORD") || "weakpassword";
    send_key "ret";
    wait_still_screen 7;

    # Create user
    type_string "5\n";
    wait_still_screen 5;
    type_string "1\n";    # create new
    wait_still_screen 5;
    type_string "3\n";    # set username
    wait_still_screen 5;
    type_string get_var("USER_LOGIN", "test");
    send_key "ret";
    wait_still_screen 5;
    type_string "5\n";    # set password
    wait_still_screen 5;
    type_string get_var("USER_PASSWORD", "weakpassword");
    send_key "ret";
    wait_still_screen 5;
    type_string get_var("USER_PASSWORD", "weakpassword");
    send_key "ret";
    wait_still_screen 5;
    type_string "6\n";    # make him an administrator
    wait_still_screen 5;
    type_string "c\n";
    wait_still_screen 7;

    assert_screen "console_initial_setup_done", 30;
    type_string "c\n";    # continue
}

sub handle_welcome_screen {
    # handle the 'welcome' screen on GNOME and KDE since F38. shared
    # in a few places
    if (check_screen "getting_started", 45) {
        if (get_var("DESKTOP") eq "kde") {
            # just closing it seems to result in it running again on
            # next boot, so let's click Skip
            click_lastmatch;
        }
        else {
            send_key "alt-f4";
            # for GNOME 40, alt-f4 doesn't work
            send_key "esc";
        }
        wait_still_screen 5;
        set_var("_WELCOME_DONE", 1);
    }
    else {
        record_soft_failure "Welcome tour missing";
    }
}

sub gnome_initial_setup {
    # Handle gnome-initial-setup, with variations for live mode (the
    # short run on live boot since F39), the pre-login  mode (when no
    # user was created during install) and post-login mode (when user
    # was created during install). post-login mode currently (2023-08)
    # unused, but may come back in future. 'livetry' indicates whether
    # to launch the installer (0) or desktop (1) at the end of live
    # flow
    my %args = (
        prelogin => 0,
        live => 0,
        livetry => 0,
        timeout => 120,
        @_
    );
    my $relnum = get_release_number;
    my $advortask = get_var("ADVISORY_OR_TASK");

    # note: when 'language' is "skipped", it's turned into a 'welcome'
    # page, which has a "Start Setup" button, not a "Next" button
    unless (check_screen ["next_button", "start_setup"], $args{timeout}) {
        record_soft_failure "g-i-s taking longer than expected to start up!";
        assert_screen ["next_button", "start_setup"], $args{timeout};
    }
    # GDM 3.24.1 dumps a cursor in the middle of the screen here...
    mouse_hide if ($args{prelogin});

    # the pages we *may* need to click 'next' on. *NOTE*: 'language'
    # is the 'welcome' page, and is in fact never truly skipped; if
    # it's configured to be skipped, it just shows without the language
    # selection widget (so it's a bare 'welcome' page). Current openQA
    # tests never see 'eula' or 'network'. You can find the upstream
    # list in gnome-initial-setup/gnome-initial-setup.c , and the skip
    # config file for Fedora is vendor.conf in the package repo.
    my @nexts = ('language', 'keyboard', 'privacy', 'timezone', 'software');
    # now, we're going to figure out how many of them this test will
    # *actually* see...
    if ($args{live}) {
        # this is the flow we see when booting an F39+ Workstation live
        # we only get language and keyboard
        @nexts = ('language', 'keyboard');
    }
    if ($args{prelogin}) {
        # 'language', 'keyboard' and 'timezone' were skipped between F28
        # and F38 in the 'new user' mode by
        # https://fedoraproject.org//wiki/Changes/ReduceInitialSetupRedundancy
        # https://bugzilla.redhat.com/show_bug.cgi?id=1474787 ,
        # except 'language' was never *really* skipped (see above)
        if ($relnum < 39 || $advortask eq "FEDORA-2023-73c4f1a802") {
            @nexts = grep { $_ ne 'keyboard' } @nexts;
            @nexts = grep { $_ ne 'timezone' } @nexts;
        }
        # From gnome-initial-setup 45~beta-3 on, no screens are
        # skipped in vendor.conf. 'language' and 'keyboard' should be
        # skipped (meaning 'language' is turned into 'welcome' and
        # 'keyboard' is really skipped) on live installs because we saw
        # them already, but this only works from anaconda 39.32.2 /
        # 40.3 onwards. network installs and disk image deployments
        # will show these screens (which is good for disk image
        # deployments, but redundant for network installs)
        elsif (match_has_tag "start_setup") {
            # if we saw start_setup, that means 'language' was skipped
            # and we can assume 'keyboard' will also be skipped
            @nexts = grep { $_ ne 'keyboard' } @nexts;
        }
    }
    else {
        # 'timezone' and 'software' are suppressed for the 'existing user'
        # form of g-i-s (upstream, not in vendor.conf)
        @nexts = grep { $_ ne 'software' } @nexts;
        @nexts = grep { $_ ne 'timezone' } @nexts;
    }

    foreach my $next (@nexts) {
        # give animations a bit to settle down
        wait_still_screen 3;
        # click 'Next' $nexts times, moving the mouse to avoid
        # highlight problems, sleeping to give it time to get
        # to the next screen between clicks
        mouse_set(100, 100);
        if ($next eq 'language') {
            # only accept start_setup one time, to avoid matching
            # on it during transition to next screen. also accept
            # next_button as in live and existing user modes, first
            # screen has that not start_setup
            wait_screen_change { assert_and_click ["next_button", "start_setup"]; };
        }
        elsif ($next eq 'timezone') {
            assert_screen ["next_button", "next_button_inactive"];
            if (match_has_tag "next_button_inactive") {
                record_soft_failure "geolocation failed!";
                send_key "tab";
                wait_still_screen 3;
                type_very_safely "washington-d";
                send_key "down";
                send_key "ret";
            }
            wait_screen_change { assert_and_click "next_button"; };
        }
        else {
            wait_screen_change { assert_and_click "next_button"; };
        }
    }
    unless (get_var("VNC_CLIENT") || $args{live}) {
        # We should be at the GOA screen, except on VNC_CLIENT case
        # where network isn't working yet. click 'Skip' one time. If
        # it's not visible we may have hit
        # https://bugzilla.redhat.com/show_bug.cgi?id=1997310 , which
        # we'll handle as a soft failure
        mouse_set(100, 100);
        if (check_screen "skip_button", 60) {
            wait_screen_change { click_lastmatch; };
        }
        else {
            record_soft_failure "GOA screen not seen! Likely RHBZ #1997310";
        }
    }
    send_key "tab" if ($args{live} && $args{livetry});
    # on the 'live' flow, this will launch the installer
    send_key "ret";
    # we don't want to do anything further on the 'live' flow
    return if ($args{live});
    if ($args{prelogin}) {
        # create user
        my $user_login = get_var("USER_LOGIN") || "test";
        my $user_password = get_var("USER_PASSWORD") || "weakpassword";
        type_very_safely $user_login;
        wait_screen_change { assert_and_click "next_button"; };
        # temporarily (until the versions are stable) we need to check
        # whether we're on 43 or 44 here
        my $extratab = 0;
        $extratab = 1 if (check_screen 'initial_setup_44', 5);
        type_very_safely $user_password;
        send_key "tab";
        # on GNOME 44+ we need a second tab here to reach the confirm box
        send_key "tab" if ($extratab);
        type_very_safely $user_password;
        wait_screen_change { assert_and_click "next_button"; };
        send_key "ret";
    }
    else {
        handle_welcome_screen;
    }
    # don't do it again on second load
    set_var("_SETUP_DONE", 1);
}

sub _type_user_password {
    # convenience function used by anaconda_create_user, not meant
    # for direct use
    my $user_password = get_var("USER_PASSWORD") || "weakpassword";
    if (get_var("SWITCHED_LAYOUT")) {
        # we double the password, the second time using the native
        # layout, so the password has both ASCII and native characters
        desktop_switch_layout "ascii", "anaconda";
        type_very_safely $user_password;
        desktop_switch_layout "native", "anaconda";
        type_very_safely $user_password;
    }
    else {
        type_very_safely $user_password;
    }
}

sub anaconda_create_user {
    # Create a user, in the anaconda interface. This is here because
    # the same code works both during install and for initial-setup,
    # which runs post-install, so we can share it.
    my %args = (
        timeout => 90,
        @_
    );
    # For some languages, i.e. Turkish, we want to use a complicated
    # geo field to test that turkish letters will be displayed correctly
    # and that the installer will be able to handle them and change them
    # into the correct user name without special characters.
    my $geofield = get_var("USER_GECOS");
    my $user_login = get_var("USER_LOGIN") || "test";
    unless ($geofield) {
        # If geofield is not defined, let it be the same as login.
        $geofield = $user_login;
    }
    assert_and_click("anaconda_install_user_creation", timeout => $args{timeout});
    assert_screen "anaconda_install_user_creation_screen";
    # wait out animation
    wait_still_screen 2;
    # We will type the $geofield as the user name.
    type_very_safely $geofield;
    # For Turkish, we especially want to check that correct characters
    # are typed, so we will check it here.
    if (get_var("LANGUAGE") eq "turkish") {
        assert_screen("username_typed_correctly_turkish");
    }
    send_key("tab");
    # Now set the login name.
    type_very_safely($user_login);
    # And fill the password stuff.
    type_very_safely "\t\t\t";
    _type_user_password();
    wait_screen_change { send_key "tab"; };
    wait_still_screen 2;
    _type_user_password();
    # even with all our slow typing this still *sometimes* seems to
    # miss a character, so let's try again if we have a warning bar.
    # But not if we're installing with a switched layout, as those
    # will *always* result in a warning bar at this point (see below)
    if (!get_var("SWITCHED_LAYOUT") && check_screen "anaconda_warning_bar", 3) {
        wait_screen_change { send_key "shift-tab"; };
        wait_still_screen 2;
        _type_user_password();
        wait_screen_change { send_key "tab"; };
        wait_still_screen 2;
        _type_user_password();
    }
    assert_and_click "anaconda_spoke_done";
    # since 20170105, we will get a warning here when the password
    # contains non-ASCII characters. Assume only switched layouts
    # produce non-ASCII characters, though this isn't strictly true
    if (get_var('SWITCHED_LAYOUT') && check_screen "anaconda_warning_bar", 3) {
        wait_still_screen 1;
        assert_and_click "anaconda_spoke_done";
    }
}

sub check_desktop {
    # Check we're at a desktop. We do this by looking for the "apps"
    # menu button ("Activities" button on GNOME, kicker button on
    # KDE). This is set up as a helper function so we can handle
    # GNOME's behaviour of opening the overview on first login; all
    # our tests were written when GNOME *didn't* do that, so it
    # would be awkward to find all the places in them where we need
    # to close the overview. Instead, we just have this function
    # close it if it's open.
    my %args = (
        timeout => 30,
        @_
    );
    my $count = 5;
    my $activematched = 0;
    while ($count > 0) {
        $count -= 1;
        assert_screen "apps_menu_button", $args{timeout};
        if ($count == 4) {
            # GNOME 42 shows the inactive menu button briefly before
            # opening the overview. So we need to wait a bit on first
            # cycle in case GNOME is about to open the overview.
            wait_still_screen 5;
            assert_screen "apps_menu_button";
        }
        # Here's where we detect if the overview is open and close it
        if (match_has_tag "apps_menu_button_active") {
            $activematched = 1;
            wait_still_screen 5;
            send_key "super";
            wait_still_screen 5;
        }
        else {
            # this means we saw 'inactive', which is what we want
            last;
        }
    }
    if ($activematched) {
        # make sure we got to inactive after active
        die "never reached apps_menu_button_inactive!" unless (match_has_tag "apps_menu_button_inactive");
    }
}

sub download_modularity_tests {
    # Download the modularity test script, place in the system and then
    # modify the access rights to make it executable.
    my ($whitelist) = @_;
    # we need python3-yaml for the script to run
    assert_script_run 'dnf -y install python3-yaml', 180;
    assert_script_run 'curl --verbose --retry-delay 10 --max-time 30 --retry 5 -o /root/test.py https://pagure.io/fedora-qa/modularity_testing_scripts/raw/master/f/modular_functions.py', timeout => 180;
    if ($whitelist eq 'whitelist') {
        assert_script_run 'curl --verbose --retry-delay 10 --max-time 30 --retry 5 -o /root/whitelist https://pagure.io/fedora-qa/modularity_testing_scripts/raw/master/f/whitelist', timeout => 180;
    }
    assert_script_run 'chmod 755 /root/test.py';
}

sub quit_firefox {
    # Quit Firefox, handling the 'close multiple tabs' warning screen if
    # it shows up. Expects to quit to a recognizable console
    send_key "ctrl-q";
    # expect to get to either the tabs warning or a console
    if (check_screen ["user_console", "root_console", "firefox_close_tabs"], 30) {
        # if we hit a console we're good
        unless (match_has_tag("firefox_close_tabs")) {
            wait_still_screen 5;
            return;
        }
        # otherwise we hit the tabs warning, click it
        click_lastmatch;
        # again, if we hit a console, we're good
        if (check_screen ["user_console", "root_console"], 30) {
            wait_still_screen 5;
            return;
        }
    }
    # if we reach here, we didn't see a console. This is most likely
    # https://bugzilla.redhat.com/show_bug.cgi?id=2094137 . soft fail
    # and reboot. this won't work if we need to decrypt or handle boot
    # args, but I don't think anything that calls this needs it
    record_soft_failure "No console on exit from Firefox, probably RHBZ #2094137";
    power "reset";
    boot_to_login_screen;
    console_login(user => "root", password => get_var("ROOT_PASSWORD"));
}

sub start_with_launcher {
    # Get the name of the needle with a launcher, find the launcher in the menu
    # and click on it to start the application. This function works for the
    # Gnome desktop.

    # $launcher holds the launcher needle, but some of the apps are hidden in a submenu
    # so this must be handled first to find the launcher needle.

    my ($launcher, $submenu, $group) = @_;
    $submenu //= '';
    $group //= '';
    my $desktop = get_var('DESKTOP');

    my $item_to_check = $submenu || $launcher;
    # The following varies for different desktops.
    if ($desktop eq 'gnome') {
        # Start the Activities page
        send_key 'super';
        wait_still_screen 5;

        # Click on the menu icon to come into the menus
        assert_and_click 'overview_app_grid';
        wait_still_screen 5;

        # Find the application launcher in the current menu page.
        # If it cannot be found there, hit PageDown to go to another page.

        send_key_until_needlematch($item_to_check, 'pgdn', 5, 3);

        # If there was a submenu, click on that first.
        if ($submenu) {
            assert_and_click $submenu;
            wait_still_screen 5;
        }
        # Click on the launcher
        if (!check_screen($launcher)) {
            # On F33+, this subwindow thingy scrolls horizontally,
            # but only after we hit 'down' twice to get into it.
            send_key 'down';
            send_key 'down';
            send_key_until_needlematch($launcher, 'right', 5, 6);
        }
        assert_and_click $launcher;
        wait_still_screen 5;
    }
    else {
        die "start_with_launcher is currently only implemented on GNOME!";
    }
}


sub quit_with_shortcut {
    # Quit the application using the Alt-F4 keyboard shortcut
    send_key 'alt-f4';
    wait_still_screen 5;
    assert_screen 'workspace';

}

# For update tests (this only works if we've been through
# _repo_setup_updates), figure out which packages from the update
# are currently installed. This is here so we can do it both in
# _advisory_post and post_fail_hook.
sub advisory_get_installed_packages {
    # can't do anything useful when testing a side tag
    return if (get_var("TAG"));
    # sanity check
    die "advisory_get_installed_packages, but ISO_2 is not attached!" unless (get_var("ISO_2"));
    mount_update_image;
    # bail out if the file doesn't exist: this is in case we get
    # here in the post-fail hook but we failed before creating it
    return if script_run "test -f /mnt/updateiso/updatepkgs.txt";
    assert_script_run 'rpm -qa --qf "%{SOURCERPM} %{NAME} %{EPOCHNUM} %{VERSION} %{RELEASE}\n" | sort -u > /tmp/allpkgs.txt', timeout => 90;
    # this finds lines which appear in both files
    # http://www.unix.com/unix-for-dummies-questions-and-answers/34549-find-matching-lines-between-2-files.html
    if (script_run 'comm -12 /tmp/allpkgs.txt /mnt/updateiso/updatepkgs.txt > /mnt/testedpkgs.txt') {
        # occasionally, for some reason, it's unhappy about sorting;
        # we shouldn't fail the test in this case, just upload the
        # files so we can see why...
        upload_logs "/tmp/allpkgs.txt", failok => 1;
        upload_logs "/mnt/updateiso/updatepkgs.txt", failok => 1;
    }
    # we'll try and upload the output even if comm 'failed', as it
    # does in fact still write it in some cases
    upload_logs "/mnt/testedpkgs.txt", failok => 1;
}

sub advisory_check_nonmatching_packages {
    # For update tests (this only works if we've been through
    # _repo_setup_updates), figure out if we have a different version
    # of any package from the update installed - this indicates a
    # problem, it likely means a dep issue meant dnf installed an
    # older version from the frozen release repo
    my %args = (
        fatal => 1,
        @_
    );
    # can't do anything useful when testing a side tag
    return if (get_var("TAG"));
    # sanity check
    die "advisory_check_nonmatching_packages called, but ISO_2 is not attached!" unless (get_var("ISO_2"));
    mount_update_image;
    # bail out if the file doesn't exist: this is in case we get
    # here in the post-fail hook but we failed before creating it
    return if script_run "test -f /mnt/updateiso/updatepkgnames.txt";
    # if this fails in advisory_post, we don't want to do it *again*
    # unnecessarily in post_fail_hook
    return if (get_var("_ACNMP_DONE"));
    script_run 'touch /tmp/installedupdatepkgs.txt';
    # this creates /tmp/installedupdatepkgs.txt as a sorted list of installed
    # packages with the same name as packages from the update, in the same form
    # as /mnt/updateiso/updatepkgs.txt. The '--last | head -1' tries to handle the
    # problem of installonly packages like the kernel, where we wind up with
    # *multiple* versions installed after the update; the first line of output
    # for any given package with --last is the most recent version, i.e. the
    # one in the update. The sed replaces the caret - "^" - with "\^" (literal
    # slash then a caret) in the package NVRA; this is necessary to workaround
    # a bug in RPM - https://bugzilla.redhat.com/show_bug.cgi?id=2002038 . It
    # can be removed when that bug is fixed. Yes, it really needs eight slashes
    # (we need four to reach bash, and half of them get eaten by perl or
    # something along the way). Yes, it only works with *single* quotes. Yes,
    # I hate escaping
    script_run 'for pkg in $(cat /mnt/updateiso/updatepkgnames.txt); do rpm -q $pkg && rpm -q $pkg --last | head -1 | cut -d" " -f1 | sed -e \'s,\^,\\\\\\\\^,g\' | xargs rpm -q --qf "%{SOURCERPM} %{NAME} %{EPOCHNUM} %{VERSION} %{RELEASE}\n" >> /tmp/installedupdatepkgs.txt; done', timeout => 180;
    script_run 'sort -u -o /tmp/installedupdatepkgs.txt /tmp/installedupdatepkgs.txt';
    # for debugging, may as well always upload these, can't hurt anything
    upload_logs "/tmp/installedupdatepkgs.txt", failok => 1;
    upload_logs "/mnt/updateiso/updatepkgs.txt", failok => 1;
    # download the check script and run it
    assert_script_run 'curl --verbose --retry-delay 10 --max-time 30 --retry 5 -o updvercheck.py https://pagure.io/fedora-qa/os-autoinst-distri-fedora/raw/main/f/updvercheck.py', timeout => 180;
    my $advisory = get_var("ADVISORY");
    my $cmd = 'python3 ./updvercheck.py /mnt/updateiso/updatepkgs.txt /tmp/installedupdatepkgs.txt';
    $cmd .= " $advisory" if ($advisory);
    my $ret = script_run $cmd;
    # 2 is warnings only, 3 is problems, 1 means the script died in
    # some other way (probably a bug)
    if ($ret == 2) {
        record_soft_failure "Some update package(s) not installed, but this is probably OK, see script output";
    }
    if ($ret == 1 || $ret == 3) {
        my $message = "Package(s) from update not installed when it should have been! See script output";
        $message = "Script failed unexpectedly!" if ($ret == 1);
        if ($args{fatal}) {
            set_var("_ACNMP_DONE", "1");
            die $message;
        }
        else {
            # if we're already in post_fail_hook, we don't want to die again
            record_info $message;
        }
    }
}

sub select_rescue_mode {
    # handle bootloader screen
    assert_screen "bootloader", 30;
    if (get_var('OFW')) {
        # select "rescue system" directly
        send_key "down";
        send_key "down";
        send_key "ret";
    }
    else {
        # select troubleshooting
        send_key "down";
        send_key "ret";
        # select "rescue system"
        if (get_var('UEFI')) {
            send_key "down";
            # we need this on aarch64 till #1661288 is resolved
            if (get_var('ARCH') eq 'aarch64') {
                send_key "e";
                # duped with do_bootloader, sadly...
                for (1 .. 50) {
                    send_key 'down';
                }
                sleep 1;
                send_key 'up';
                sleep 1;
                send_key 'up';
                send_key "end";
                type_safely " console=tty0";
                send_key "ctrl-x";
            }
            else {
                send_key "ret";
            }
        }
        else {
            type_string "r\n";
        }
    }

    assert_screen "rescue_select", 180;    # it takes time to start anaconda
}

sub copy_devcdrom_as_isofile {
    # copy /dev/cdrom as iso file and verify checksum is same
    # as cdrom previously retrieved from ISO_URL
    my $isoname = shift;
    assert_script_run "dd if=/dev/cdrom of=$isoname", 360;
    # verify iso checksum
    my $cdurl = get_var('ISO_URL');
    # ISO_URL may not be set if we POSTed manually or something; just assume
    # we're OK in that case
    return unless $cdurl;
    my $cmd = <<EOF;
urld="$cdurl"; urld=\${urld%/*}; chkf=\$(curl -fs \$urld/ |grep CHECKSUM | sed -E 's/.*href=.//; s/\".*//') && curl -f \$urld/\$chkf -o /tmp/x
chkref=\$(grep -E 'SHA256.*dvd' /tmp/x | sed -e 's/.*= //') && echo "\$chkref $isoname" >/tmp/x
sha256sum -c /tmp/x
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
}

sub menu_launch_type {
    # Launch an application in a graphical environment, by opening a
    # launcher, typing the specified string and hitting enter. Pass
    # the string to be typed to launch whatever it is you want.
    my $app = shift;
    # To overcome BZ2097208, let's move the mouse out of the way
    # and give the launcher some time to take the correct focus.
    if (get_var("DESKTOP") eq "kde") {
        diag("Moving the mouse away from the launcher.");
        mouse_set(1, 1);
    }
    send_key 'super';
    # srsly KDE y u so slo
    wait_still_screen 3;
    type_very_safely $app;
    # Wait for KDE to place focus correctly.
    sleep 2;
    send_key 'ret';
}

sub tell_source {
    # This helper function identifies the Subvariant of the tested system.
    # For the purposes of identification testing, we are only interested
    # if the system is Workstation, Server, or something else, because,
    # except Workstation and Server, there are no graphical differences
    # between various spins and isos.
    my $iso = get_var('SUBVARIANT');
    $iso = lc($iso);
    if ($iso eq 'workstation' or $iso eq 'server') {
        # do nothing, but don't hit else
    }
    elsif ($iso eq 'atomichost') {
        $iso = 'atomic';
    }
    elsif ($iso eq 'silverblue') {
        $iso = 'workstation';
    }
    else {
        $iso = 'generic';
    }
    return $iso;
}

sub check_left_bar {
    # This method is used by identification tests to check whether the Anaconda
    # bar on the left side of the screen corresponds with the correct version.
    # It looks different for Server, Workstation and others.
    my $source = tell_source;
    assert_screen "leftbar_${source}";
}

sub check_top_bar {
    # This method is used by identification tests to check whether the
    # top bar in Anaconda corresponds with the correct version of the spin.
    my $source = tell_source;
    assert_screen "topbar_${source}";
}

sub check_prerelease {
    # This method is used by identification tests to check if
    # Anaconda shows the PRERELEASE tag on various screens. These are
    # the rules anaconda follows for deciding whether to do this, as
    # of 2020-05-07:

    # 1. If there's a /.buildstamp and/or /tmp/product/.buildstamp file
    # the installer environment, and/or the environment variable
    # PRODBUILDPATH is set and points to a file that exists, it reads
    # config from those file(s), in that order of precedence, and if
    # the key 'IsFinal' exists in the section 'Main', its value is
    # used as anaconda's `product.isFinal`. Installer images built by
    # lorax have this buildstamp file, and it always sets IsFinal: if
    # --isfinal was passed to lorax it is set to True, if not it is set
    # to False. Whether lorax is run with --isfinal can be specified
    # in the Pungi config, but there's also a heuristic: it usually
    # defaults to False, but if the compose has a label and it's an
    # 'RC' or 'Update' or 'SecurityFix' compose (see definition of
    # SUPPORTED_MILESTONES in productmd.composeinfo), the default is
    # True. AFAICS, Fedora's pungi configs don't explicitly set this,
    # but rely on the heuristic. So for installer images, we expect
    # isFinal to be True for RC candidate composes and post-release
    # nightly Cloud, IoT etc. composes (these are also marked as 'RC'
    # composes), but False for Rawhide and Branched nightly composes
    # and Beta candidate composes. For installer images built by our
    # own _installer_build test, we control whether --isfinal is set
    # or not; we pass it if the update is for a stable release, we do
    # not pass it if the update is for Branched. Live images do not
    # have the buildstamp file.

    # 2. If there's no buildstamp file, the value of the environment
    # variable ANACONDA_ISFINAL is used as `product.isFinal`, default
    # of False if that environment var is not set. The live installer
    # wrapper script sets ANACONDA_ISFINAL based on the release field
    # of whatever package provides system-release: if it starts with
    # "0.", it sets ANACONA_ISFINAL to "false", otherwise it sets it
    # to "true". So for live images, we expect isFinal to be True
    # unless the fedora-release-common package release starts with 0.

    # 3. If `product.isFinal` is False, the pre-release warning and
    # tags are shown; if it is False, they are not shown.

    # We don't really need to check this stuff for update tests, as
    # the only installer images we test on updates are ones we build
    # ourselves; there's no value to this check for those really.
    # For compose tests, we will expect to see the pre-release tags if
    # the compose is Rawhide, or a Beta candidate, or it's a nightly
    # and we're checking an installer image. If it's an RC or Updates
    # candidate, or a respin release, we expect NOT to see the tags.
    # If it's a nightly and we're checking a live image, we don't do
    # the check.

    # bail if this is an update test
    return if (get_var("ADVISORY_OR_TASK"));

    # 0 means "tags MUST NOT be shown", 1 means "tags MUST be shown",
    # any other value means we don't care
    my $prerelease = 10;

    # if this is RC or update compose we absolutely *MUST NOT* see tags
    my $label = get_var("LABEL");
    $prerelease = 0 if ($label =~ /^(RC|Update)-/);
    # if it's a Beta compose we *MUST* see tags
    $prerelease = 1 if ($label =~ /^Beta-/);
    my $version = get_var('VERSION');
    # if it's Rawhide we *MUST* see tags
    $prerelease = 1 if ($version eq "Rawhide");
    my $build = get_var('BUILD');
    # if it's a nightly installer image we should see tags
    $prerelease = 1 if ($build =~ /\.n\.\d+/ && !get_var("LIVE"));
    # if it's a respin compose we *MUST NOT* see tags
    $prerelease = 0 if ($build =~ /Respin/);
    # we *could* go to a console and parse fedora-release-common
    # to decide if a nightly live image should have tags or not, but
    # it seems absurd as we're almost reinventing the code that
    # decides whether to show the tags, at that point, and it's not
    # really a big deal either way whether a nightly live image has
    # the tags or not. So we don't.

    # For all prerelease requiring ISOs, assert that prerelease is there.
    if ($prerelease == 1) {
        assert_screen "prerelease_note";
    }
    elsif ($prerelease == 0) {
        # If the prerelease note is shown, where it should not be, die!
        if (check_screen "prerelease_note") {
            die "The PRERELEASE tag is shown, but it should NOT be.";
        }
    }
}

sub check_version {
    # This function checks if the correct version is display during installation
    # in Anaconda, i.e. nonlive media showing Rawhide when Rawhide and version numbers
    # when not Rawhide, while live media always showing version numbers.

    my $version = lc(get_var('VERSION'));
    if ($version eq 'rawhide' && get_var('LIVE')) {
        $version = get_var('RAWREL');
    }
    assert_screen "version_${version}_ident";
}

sub spell_version_number {
    my $version = shift;
    # spelt version of Rawhide is...Rawhide
    return "Rawhide" if ($version eq 'Rawhide');
    my %ones = (
        "0" => "Zero",
        "1" => "One",
        "2" => "Two",
        "3" => "Three",
        "4" => "Four",
        "5" => "Five",
        "6" => "Six",
        "7" => "Seven",
        "8" => "Eight",
        "9" => "Nine",
    );
    my %tens = (
        "2" => "Twenty",
        "3" => "Thirty",
        "4" => "Fourty",
        "5" => "Fifty",
        "6" => "Sixty",
        "7" => "Seventy",
        "8" => "Eighty",
        "9" => "Ninety",
    );

    my $ten = substr($version, 0, 1);
    my $one = substr($version, 1, 1);
    my $speltnum = "";
    if ($one eq "0") {
        $speltnum = "$tens{$ten}";
    }
    else {
        $speltnum = "$tens{$ten} $ones{$one}";
    }
    return $speltnum;
}

sub rec_log {
    my ($line, $condition, $failref, $filename) = @_;
    $filename ||= '/tmp/os-release.log';
    if ($condition) {
        $line = "${line} - SUCCEEDED\n";
    }
    else {
        push @$failref, $line;
        $line = "${line} - FAILED\n";
    }
    script_run "echo \"$line\" >> $filename";

}

# In each application test, when the application is started successfully, it
# will register to the list of applications.
sub register_application {
    my $application = shift;
    push(@application_list, $application);
    print("APPLICATION REGISTERED: $application \n");
}

# The KDE desktop tests are very difficult to maintain, because the transparency
# of the menu requires a lot of different needles to cover the elements.
# Therefore it is useful to change the background to a solid colour.
# Since many needles have been already created with a black background
# we will keep it that way. The following code has been taken from the
# KDE startstop tests but it is good to have it here, because it will be
# needed more often now, it seems.
sub solidify_wallpaper {
    my $desktop = get_var("DESKTOP");
    if ($desktop eq "kde") {
        # Run the Desktop settings
        hold_key 'alt';
        send_key 'd';
        send_key 's';
        release_key 'alt';
        # give the window a few seconds to stabilize
        wait_still_screen 3;
        # Select type of background
        assert_and_click "deskset_select_type";
        wait_still_screen 2;
        # Select plain color type
        assert_and_click "deskset_plain_color";
        wait_still_screen 2;
        # Open colors selection
        assert_and_click "deskset_select_color";
        wait_still_screen 2;
        # Select black
        assert_and_click "deskset_select_black";
        wait_still_screen 2;
        # Confirm
        assert_and_click "kde_ok";
        wait_still_screen 2;
        # Close the application
        assert_and_click "kde_ok";
    }
    elsif ($desktop eq "gnome") {
        # Start the terminal to set up backgrounds.
        menu_launch_type "gnome-terminal";
        # wait to be sure it's fully open
        wait_still_screen(stilltime => 5, similarity_level => 38);
        # When the application opens, run command in it to set the background to black
        type_very_safely "gsettings set org.gnome.desktop.background picture-uri ''";
        send_key 'ret';
        wait_still_screen(stilltime => 2, similarity_level => 38);
        type_very_safely "gsettings set org.gnome.desktop.background primary-color '#000000'";
        send_key 'ret';
        wait_still_screen(stilltime => 2, similarity_level => 38);
        quit_with_shortcut();
        # check that is has changed color
        assert_screen 'apps_settings_screen_black';
    }
}

# This routine is used in Desktop test suites, such as Evince or Gedit.
# It checks if git is installed and installs it, if necessary.
sub check_and_install_git {
    unless (get_var("CANNED")) {
        if (script_run("rpm -q git")) {
            assert_script_run("dnf install -y git");
        }
    }
}

# This routine is used in Desktop test suites. It downloads the test data from
# the repository and populates the directory structure.
# The data repository is located at https://pagure.io/fedora-qa/openqa_testdata.

sub download_testdata {
    # Navigate to the user's home directory
    my $user = get_var("USER_LOGIN") // "test";
    assert_script_run("cd /home/$user/");
    # Create a temporary directory to unpack the zipped file.
    assert_script_run("mkdir temp");
    assert_script_run("cd temp");
    # Download the compressed file with the repository content.
    assert_script_run("curl --verbose --retry-delay 10 --max-time 120 --retry 5 -o repository.tar.gz https://pagure.io/fedora-qa/openqa_testdata/blob/thetree/f/repository.tar.gz", timeout => 600);
    # Untar it.
    assert_script_run("tar -zxvf repository.tar.gz");
    # Copy out the files into the VMs directory structure.
    assert_script_run("cp music/* /home/$user/Music");
    assert_script_run("cp documents/* /home/$user/Documents");
    assert_script_run("cp pictures/* /home/$user/Pictures");
    assert_script_run("cp video/* /home/$user/Videos");
    assert_script_run("cp reference/* /home/$user/");
    # Delete the temporary directory and the downloaded file.
    assert_script_run("cd");
    assert_script_run("rm -rf /home/$user/temp");
    # Change ownership
    assert_script_run("chown -R test:test /home/$user/");
}

# On Fedora, the serial console is not writable for regular users which lames
# some of the openQA commands that send messages to the serial console to check
# that a command has finished, for example assert_script_run, etc.
# This routine changes the rights on the serial console file and makes it
# writable for everyone, so that those commands work. This is actually very useful
# for testing commands from users' perspective. The routine also handles becoming the root.
# We agree that this is not the "correct" way, to enable users to type onto serial console
# and that it correctly should be done via groups (dialout) but that would require rebooting
# the virtual machine. Therefore we do it this way, which has immediate effect.
sub make_serial_writable {
    become_root();
    sleep 2;
    # Make serial console writable for everyone.
    enter_cmd("chmod 666 /dev/${serialdev}");
    sleep 2;
    # Exit the root account
    enter_cmd("exit");
    sleep 2;
}

1;
