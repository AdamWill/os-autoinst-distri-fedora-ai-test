use base "anacondatest";
use strict;
use lockapi;
use testapi;
use utils;
use tapnet;
use anaconda;

sub _handle_incomplete_hub {
    if (match_has_tag "anaconda_main_hub_keyboard_layout_incomplete") {
        # workaround IoT/osbuild issue
        # https://github.com/osbuild/images/issues/309
        # by visiting the incomplete spokes
        click_lastmatch;
        wait_still_screen 3;
        assert_and_click "anaconda_spoke_done";
        # for animation
        wait_still_screen 3;
        assert_and_click "anaconda_main_hub_time_date_incomplete";
        wait_still_screen 3;
        assert_and_click "anaconda_spoke_done";
        wait_still_screen 3;
        send_key "shift-tab";
    }
}

sub run {
    my $self = shift;
    my $arch = get_var("ARCH");
    if (get_var("IS_PXE")) {
        # PXE tests have DELAYED_START set, so VM is not running yet,
        # because if we boot immediately PXE will time out waiting for
        # DHCP before the support server is ready. So we wait here for
        # support server to be ready, then go ahead and start the VM
        mutex_lock "support_ready";
        mutex_unlock "support_ready";
        resume_vm;
    }

    # construct the kernel params. the trick here is to wind up with
    # spaced params if GRUB or GRUBADD is set, and just spaces if not,
    # then check if we got all spaces. We wind up with a harmless
    # extra space if GRUBADD is set but GRUB is not.
    my $params = "";
    $params .= get_var("GRUB", "") . " ";
    $params .= get_var("GRUBADD", "") . " ";
    # Construct inst.repo arg for REPOSITORY_VARIATION
    my $repourl = get_var("REPOSITORY_VARIATION");
    if ($repourl) {
        $params .= "inst.repo=" . get_full_repo($repourl) . " ";
    }
    # Construct inst.addrepo arg for ADD_REPOSITORY_VARIATION
    my $repourl = get_var("ADD_REPOSITORY_VARIATION");
    if ($repourl) {
        $params .= "inst.addrepo=addrepo,$repourl ";
    }
    # for update tests
    if (get_var("ADVISORY_OR_TASK")) {
        # add workaround repo if there is one
        $params .= "inst.addrepo=workarounds,nfs://172.16.2.110:/mnt/workarounds_repo " if (get_workarounds);
        # add tag repo if we're on rawhide
        my $version = get_var("VERSION");
        if ($version eq get_var("RAWREL")) {
            $params .= "inst.addrepo=koji-rawhide,https://kojipkgs.fedoraproject.org/repos/f${version}-build/latest/${arch} ";
        }
    }
    if (get_var("ANACONDA_TEXT")) {
        $params .= "inst.text ";
        # we need this on aarch64 till #1594402 is resolved,
        # and we also can utilize this if we want to run this
        # over the serial console.
        $params .= "console=tty0 " if ($arch eq "aarch64");
        # when the text installation should run over the serial console,
        # we have to add some more parametres to grub. Although, the written
        # test case recommends using ttyS0, OpenQA only uses that console for
        # displaying information but does not accept key strokes. Therefore,
        # let us use a real virtio console here.
        if (get_var("SERIAL_CONSOLE")) {
            # this is icky. on ppc64 (OFW), virtio-console is hvc1 and
            # virtio-console1 is hvc2, because the 'standard' serial
            # terminal is hvc0 (the firmware does this or something).
            # On other arches, the 'standard' serial terminal is ttyS0,
            # so virtio-console becomes hvc0 and virtio-console1 is
            # hvc1. We want anaconda to wind up on the console that is
            # virtio-console1 in both cases
            if (get_var("OFW")) {
                $params .= "console=hvc2 ";
            }
            else {
                $params .= "console=hvc1 ";
            }
        }
    }
    # inst.debug enables memory use tracking
    $params .= "debug" if get_var("MEMCHECK");
    # ternary: set $params to "" if it contains only spaces
    $params = $params =~ /^\s+$/ ? "" : $params;

    # set mutex wait if necessary
    my $mutex = get_var("INSTALL_UNLOCK");

    # we need a longer timeout for the PXE boot test
    my $timeout = 60;
    $timeout = 120 if (get_var("IS_PXE"));

    # call do_bootloader with postinstall=0, the params, and the mutex,
    # unless we're a VNC install client (no bootloader there)
    unless (get_var("VNC_CLIENT")) {
        do_bootloader(postinstall => 0, params => $params, mutex => $mutex, timeout => $timeout);
    }

    # Read variables for identification tests (see further).
    my $identification = get_var('IDENTIFICATION');
    # proceed to installer
    if (get_var("KICKSTART") || get_var("VNC_SERVER")) {
        # wait for the bootloader *here* - in a test that inherits from
        # anacondatest - so that if something goes wrong during install,
        # we get anaconda logs. sleep a bit first so we don't get a
        # match for the installer bootloader if it hangs around for a
        # while after do_bootloader finishes (in PXE case it does)
        sleep 60;
        assert_screen "bootloader", 1800;
    }
    else {
        if (get_var("ANACONDA_TEXT")) {
            # select that we don't want to start VNC; we want to run in text mode
            if (get_var("SERIAL_CONSOLE")) {
                # we direct the installer to virtio-console1, and use
                # virtio-console as a root console
                select_console('user-virtio-console');
                my $match = wait_serial ["Use text mode", "Installation"], timeout => 120;
                die "Anaconda has not started." unless ($match);
                if ($match =~ m/Use text mode/) {
                    type_string "2\n";
                    die "Text version of Anaconda has not started." unless (wait_serial "Installation");
                }
            }
            else {
                assert_screen ["anaconda_use_text_mode", "anaconda_main_hub_text"], 300;
                if (match_has_tag "anaconda_use_text_mode") {
                    type_string "2\n";
                    assert_screen "anaconda_main_hub_text", 60;
                }
            }
        }
        else {
            if (get_var('LIVE')) {
                # on lives, we have to explicitly launch anaconda
                my $launched = 0;
                my $count = 5;
                # i3 got no real desktop, so we need to launch liveinst via the launcher
                if (get_var('DESKTOP') eq 'i3') {
                    if (check_screen("getting_started", timeout => 300)) {
                        send_key("esc");
                    }
                    x11_start_program("liveinst");
                    # We have launched Anaconda, so we set $launched to skip
                    # starting it again later in the general part of the code.
                    $launched = 1;
                }
                else {
                    while ($count > 0) {
                        $count -= 1;
                        assert_screen ["live_start_anaconda_icon", "apps_menu_button_active", "next_button"], 300;
                        if (match_has_tag "next_button") {
                            # we're on F39+ Workstation and looking at gnome-initial-setup
                            # completing g-i-s launches the installer
                            gnome_initial_setup(live => 1);
                            $launched = 1;
                        }
                        if (match_has_tag "apps_menu_button_active") {
                            # give GNOME some time to be sure it's done starting up
                            # and ready for input
                            wait_still_screen 5;
                            send_key "super";
                            wait_still_screen 5;
                        }
                        else {
                            # this means we saw the launcher, which is what we want
                            last;
                        }
                    }
                }
                # if we hit the g-i-s flow we already launched
                unless ($launched) {
                    # for KDE we need to double-click
                    my $relnum = get_release_number;
                    my $dclick = 0;
                    $dclick = 1 if (get_var("DESKTOP") eq "kde");
                    # FIXME launching the installer sometimes fails on KDE
                    # https://bugzilla.redhat.com/show_bug.cgi?id=2280840
                    my $tries = 5;
                    while ($tries) {
                        $tries -= 1;
                        assert_and_click("live_start_anaconda_icon", dclick => $dclick);
                        last if (check_screen ["anaconda_select_install_lang", "anaconda_webui_welcome"], 180);
                        die "Launching installer failed after 5 tries!" unless ($tries);
                    }
                }
            }
            # wait for anaconda to appear
            assert_screen ["anaconda_select_install_lang", "anaconda_webui_welcome"], 300;
            # on webUI path we are done now, also set a var so later
            # tests know if we're on the webUI path
            if (match_has_tag "anaconda_webui_welcome") {
                set_var("_ANACONDA_WEBUI", 1);
                return;
            }
            # we click to work around RHBZ #1566066 if it happens
            click_lastmatch;
            my $language = get_var('LANGUAGE') || 'english';
            assert_and_click("anaconda_select_install_lang", timeout => 300);

            # Select install language
            wait_screen_change { assert_and_click "anaconda_select_install_lang_input"; };
            type_safely $language;
            # Needle filtering in main.pm ensures we will only look for the
            # appropriate language, here
            assert_and_click "anaconda_select_install_lang_filtered";
            assert_screen "anaconda_select_install_lang_selected", 10;
            assert_and_click "anaconda_select_install_lang_continue";

            # wait 180 secs for hub or Rawhide warning dialog to appear
            # (per https://bugzilla.redhat.com/show_bug.cgi?id=1666112
            # the nag screen can take a LONG time to appear sometimes).
            # If the hub appears, return - we're done now. If Rawhide
            # warning dialog appears, accept it.
            if (check_screen ["anaconda_rawhide_accept_fate", "anaconda_main_hub"], 180) {
                if (match_has_tag("anaconda_rawhide_accept_fate")) {
                    assert_and_click "anaconda_rawhide_accept_fate";
                }
                else {
                    # this is when the hub appeared already, we're done
                    _handle_incomplete_hub;
                    return;
                }
            }

            # If we want to test self identification, in the test suite
            # we set "identification" to "true".
            # Here, we will watch for the graphical elements in Anaconda main hub.
            my $branched = get_var('VERSION');
            if ($identification eq 'true' or ($branched ne "Rawhide" && lc($branched) ne "eln")) {
                check_left_bar();    # See utils.pm
                check_prerelease();
                check_version();
            }
            # This is where we get to if we accepted fate above, *or*
            # didn't match anything: if the Rawhide warning didn't
            # show by now it never will, so we'll just wait for the
            # hub to show up.
            assert_screen "anaconda_main_hub", 900;
            _handle_incomplete_hub;
        }
    }
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
