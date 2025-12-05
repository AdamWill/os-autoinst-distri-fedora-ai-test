use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    my $admin = get_var("REALMD_ADMIN_USER", "admin");
    my $tcadmin = ucfirst($admin);
    my $domain = get_var("REALMD_DOMAIN", "test.openqa.fedoraproject.org");
    my $shortdom = uc((split(/\./, $domain))[0]);
    my $udomain = uc($domain);
    my $qdomain = quotemeta($domain);
    my $qudomain = uc($qdomain);
    # switch to tty1 (we're usually there already, but just in case
    # we're carrying on from a failed freeipa_webui that didn't fail
    # at tty1)
    select_console "tty1-console";
    wait_still_screen 1;
    if (get_var("KICKSTART")) {
        # we don't have sssd debugging enabled yet
        assert_script_run 'dnf -y install sssd-tools', 240;
        assert_script_run 'sss_debuglevel 9';
        # magic wait for AD test to avoid getent passwd check fails
        sleep 15 if ($domain =~ m/samdom/);
    }
    # check domain is listed in 'realm list'
    validate_script_output 'realm list', sub { $_ =~ m/domain-name: $qdomain.*configured: kerberos-member/s };
    # check we can resolve domain accounts
    if ($domain =~ m/samdom/) {
        # give this two tries, to see if it helps the problem where
        # it sometimes fails for no reason
        if (script_run "getent passwd '$shortdom\\$tcadmin'") {
            assert_script_run "getent passwd '$shortdom\\$tcadmin'";
        }
    }
    else {
        assert_script_run "getent passwd $admin\@$udomain";
    }
    # check keytab entries
    # on AD clients, this isn't automatically installed
    assert_script_run "dnf -y install krb5-workstation", 180;
    my $hostname = script_output 'hostname';
    my $qhost = quotemeta($hostname);
    validate_script_output 'klist -k', sub { $_ =~ m/$qhost\@$qudomain/ };
    # check we can kinit with the host principal
    if ($domain =~ m/samdom/) {
        my $shorthost = uc((split(/\./, $hostname))[0]);
        assert_script_run "kinit -k $shorthost\\\$\@$udomain";
    }
    else {
        assert_script_run "kinit -k host/$hostname\@$udomain";
    }
    # Set a longer timeout for login(1) to workaround RHBZ #1661273
    assert_script_run 'echo "LOGIN_TIMEOUT 180" >> /etc/login.defs';
    # switch to tty2 for login tests
    select_console "tty2-console";
    # try and login as test1, should work
    console_login(user => "test1\@$domain", password => 'batterystaple');
    type_string "exit\n";
    unless ($domain =~ m/samdom/) {
        # try and login as test2, should fail. we cannot use console_login
        # as it takes 10 seconds to complete when login fails, and
        # "permission denied" message doesn't last that long
        sleep 2;
        assert_screen "text_console_login";
        type_string "test2\@$udomain\n";
        assert_screen "console_password_required";
        type_string "batterystaple\n";
        assert_screen "login_permission_denied";
    }
}


sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
