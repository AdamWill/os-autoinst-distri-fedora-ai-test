use base "anacondatest";
use strict;
use testapi;
use anaconda;

sub run {
    my $self = shift;
    webui_custom_start;
    webui_custom_create_disklabel;
    webui_custom_boot_partitions;

    webui_custom_add_partition(filesystem => 'xfs', mountpoint => '/');

    assert_and_click "anaconda_webui_custom_return";
    assert_and_click "anaconda_webui_continue";
    assert_screen "anaconda_webui_installmethod";
    assert_and_click "anaconda_webui_next";
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
