package i3;

use strict;

use base 'Exporter';
use Exporter;

use testapi;
use utils;

our @EXPORT = qw/create_user_i3_config/;

sub create_user_i3_config {
    my %args = @_;
    my $login = $args{login};

    assert_script_run("mkdir -p /home/$login/.config/i3/");
    # ensure that no alias of cp prevents an existing config from being overwritten
    assert_script_run("/usr/bin/cp -f /etc/i3/config /home/$login/.config/i3/config");
    assert_script_run("sed -i '/i3-config-wizard/d' /home/$login/.config/i3/config");
    assert_script_run "chown -R $login:$login /home/$login/.config";
    assert_script_run "restorecon -vr /home/$login/.config";
}

