use base "installedtest";
use strict;
use testapi;
use utils;

sub run {

    my $self = shift;
    $self->root_console(tty => 3);
    if (get_var("ARCH") eq "aarch64") {
        # this should stop audit messages screwing things up
        assert_script_run "rpm-ostree kargs --append=audit=0";
        script_run "systemctl reboot", 0;
        boot_to_login_screen;
        $self->root_console(tty => 3);
    }

    # list available branches
    my $subv = lc(get_var("SUBVARIANT"));
    my $remote = "fedora";
    $remote = "fedora-iot" if ($subv eq "iot");
    assert_script_run "ostree remote refs $remote";

    # get current branch
    my $current = script_output "rpm-ostree status -b | grep fedora";
    if (get_var("ADVISORY_OR_TASK")) {
        die "Expected 'fedora-openqa' ref not deployed!" unless ($current =~ m/fedora-openqa/);
    }

    my $arch = lc(get_var("ARCH"));

    # decide target
    my $rebase;
    my $target;
    if ($current =~ "iot") {
        # previously we did this:
        #$rebase = $current =~ "stable" ? "devel" : "stable";
        # but we cannot rebase from F39+ to <F39:
        # https://github.com/fedora-silverblue/issue-tracker/issues/470
        #  so let's make sure we don't do that. This can be reverted
        # when F39 is stable
        $rebase = $current =~ "devel" ? "rawhide" : "devel";
        $target = "fedora/${rebase}/${arch}/iot";
    }
    elsif ($current =~ "silverblue") {
        my $relnum = get_release_number;
        $rebase = $relnum - 1;
        # special case: rebasing from >41 to 41 doesn't work
        $rebase = 43 if ($rebase == 41);
        # on update tests, just rebase to the 'official' ref for the
        # release, as opposed to the custom ref we used when building;
        # this should be more reliable than a different release
        $rebase = $relnum if (get_var("ADVISORY_OR_TASK"));
        $rebase = "rawhide" if ($rebase eq get_var("RAWREL"));
        $target = "fedora/${rebase}/${arch}/silverblue";
    }
    elsif ($current =~ "coreos") {
        $rebase = $current =~ "stable" ? "testing" : "stable";
        $target = "fedora:fedora/${arch}/coreos/${rebase}";
    }

    # rebase to the chosen target
    validate_script_output "rpm-ostree rebase $target --bypass-driver", sub { m/systemctl reboot/ }, 300;
    script_run "systemctl reboot", 0;

    boot_to_login_screen;
    $self->root_console(tty => 3);

    # check booted branch to make sure successful rebase
    validate_script_output "rpm-ostree status -b", sub { m/$target/ }, 300;

    # rollback and reboot
    validate_script_output "rpm-ostree rollback", sub { m/systemctl reboot/ }, 300;
    script_run "systemctl reboot", 0;
    boot_to_login_screen;
    $self->root_console(tty => 3);

    # check to make sure rollback successful
    validate_script_output "rpm-ostree status -b", sub { m/$current/ }, 300;
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
