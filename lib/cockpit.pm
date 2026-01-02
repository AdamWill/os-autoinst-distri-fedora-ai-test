package cockpit;

use strict;

use base 'Exporter';
use Exporter;
use lockapi;
use testapi;
use utils;

our @EXPORT = qw(start_cockpit select_cockpit_update check_updates);


sub start_cockpit {
    # Starting from a console, get to a browser with Cockpit (running
    # on localhost) shown. If login is truth-y, also log in. If login
    # and admin are both truthy, also gain admin privileges. Assumes
    # X and Firefox are installed.
    my %args = @_;
    $args{login} //= 0;
    $args{admin} //= 1;
    my $login = shift || 0;
    # run firefox directly in X as root. never do this, kids!
    type_string "startx /usr/bin/firefox -width 1024 -height 768 http://localhost:9090\n";
    assert_screen "cockpit_login", 60;
    wait_still_screen(stilltime => 5, similarity_level => 45);
    if ($args{login}) {
        type_safely "test";
        wait_screen_change { send_key "tab"; };
        type_safely get_var("USER_PASSWORD", "weakpassword");
        send_key "ret";
        if ($args{admin}) {
            assert_and_click "cockpit_admin_enable";
            assert_screen "cockpit_admin_password";
            type_safely get_var("USER_PASSWORD", "weakpassword");
            send_key "ret";
        }
        assert_screen "cockpit_main";
        # wait for any animation or other weirdness
        # can't use wait_still_screen because of that damn graph
        sleep 3;
    }
}

sub select_cockpit_update {
    # This method navigates to to the updates screen
    assert_and_click "cockpit_software_updates", timeout => 120;
    # wait for the updates to download
    assert_screen 'cockpit_updates_check', 300;
}

sub check_updates {
    my $logfile = shift;
    sleep 2;
    my $checkresult = script_run "dnf check-update > $logfile";
    upload_logs "$logfile", failok => 1;
    return ($checkresult);
}
