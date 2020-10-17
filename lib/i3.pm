package i3;

use strict;

use base 'Exporter';
use Exporter;

use testapi;
use utils;

our @EXPORT = qw/firstlaunch_setup get_i3_modifier create_user_i3_config launch_terminal/;


sub get_i3_modifier {
    return get_var("I3_MODIFIER", 'alt');
}

sub firstlaunch_setup {
    my %args = @_;
    my $timeout = $args{timeout} || 30;
    my $modifier = $args{modifier} || get_i3_modifier();

    die "invalid modifier $modifier, only alt and super are possible" unless (($modifier eq 'alt') || ($modifier eq 'super'));

    assert_screen('i3_firstlaunch_wizard', $timeout);

    if ($modifier eq 'alt') {
        send_key('esc', wait_screen_change => 1);
    } else {
        send_key('ret', wait_screen_change => 1);
        send_key_until_needlematch('down', 'i3_generate_config');
        send_key('ret', wait_screen_change => 1);
    }
}

sub create_user_i3_config {
    my %args = @_;

    my $login = $args{login};
    my $remove_config_wizard = $args{remove_config_wizard} || 1;

    assert_script_run("mkdir -p /home/$login/.config/i3/");
    # ensure that no alias of cp prevents an existing config from being overwritten
    assert_script_run("/usr/bin/cp -f /etc/i3/config /home/$login/.config/i3/config");
    if ($remove_config_wizard) {
        assert_script_run("sed -i '/i3-config-wizard/d' /home/$login/.config/i3/config");
    }
    assert_script_run "chown -R $login.$login /home/$login/.config";
    assert_script_run "restorecon -vr /home/$login/.config";
}

sub launch_terminal {
    send_key(get_i3_modifier() . '-ret');
    assert_screen("apps_run_terminal");
}
