use base "installedtest";
use strict;
use testapi;
use utils;

# This sets the KDE desktop background to plain black, to avoid
# needle match problems caused by transparency.

sub run {
    my $self = shift;
    # FIXME: get rid of annoying akonadi notification that never goes
    # away - https://bugzilla.redhat.com/show_bug.cgi?id=2403983
    click_lastmatch if (check_screen 'akonadi_migration_notification');
    solidify_wallpaper;
    kde_doublek_workaround;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}


1;

# vim: set sw=4 et:
