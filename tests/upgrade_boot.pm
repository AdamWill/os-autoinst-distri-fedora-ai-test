use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    # handle bootloader, if requested
    if (get_var("GRUB_POSTINSTALL")) {
        do_bootloader(postinstall => 1, params => get_var("GRUB_POSTINSTALL"));
    }

    # decrypt disks during boot if necessary
    if (get_var("ENCRYPT_PASSWORD")) {
        boot_decrypt(60);
    }

    assert_screen ['login_screen', 'ps_begin_setup'], timeout => 300;
    if (match_has_tag 'ps_begin_setup') {
        plasma_setup(userexists => 1);
        assert_screen 'login_screen';
    }
    # switch to TTY3 for both, graphical and console tests
    $self->root_console(tty => 3);
    # disable screen blanking (update can take a long time)
    script_run "setterm -blank 0";
    # adjust repo files to use mirrorlist not metalink (to avoid
    # metalink checksum timing issue causing infra repo to be rejected)
    repos_mirrorlist;
}


sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
