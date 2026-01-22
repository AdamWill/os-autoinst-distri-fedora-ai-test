use base "installedtest";
use strict;
use testapi;
use lockapi;
use mmapi;
use tapnet;
use utils;

# thanks to:
# https://fedoramagazine.org/samba-as-ad-and-domain-controller/
# https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller

sub run {
    my $self = shift;
    # login
    $self->root_console();
    # use compose repo, disable u-t, etc. unless this is an upgrade
    # test (in which case we're on the 'old' release at this point;
    # one of the upgrade test modules does repo_setup later)
    repo_setup() unless get_var("UPGRADE");
    # this seems to cause problems if it runs before clients are done
    assert_script_run "systemctl stop systemd-tmpfiles-clean.timer";
    # we need a lot of entropy for this, and we don't care how good
    # it is, so let's use haveged
    assert_script_run "dnf -y install haveged", 300;
    assert_script_run 'systemctl start haveged.service';
    # First install the necessary packages
    assert_script_run "dnf -y install samba-dc samba-tools krb5-workstation adcli", 600;
    # this has to be wiped or the provisioning will fail
    assert_script_run "rm -f /etc/samba/smb.conf";
    # configure the firewall
    assert_script_run "firewall-cmd --permanent --add-service samba-dc";
    assert_script_run "systemctl restart firewalld.service";
    # configure SELinux
    assert_script_run "setsebool -P samba_create_home_dirs=on samba_domain_controller=on samba_enable_home_dirs=on samba_portmapper=on use_samba_home_dirs=on";
    # extract our IP and hostname from POST_STATIC
    my $poststatic = get_var("POST_STATIC");
    my ($ip, $hostname) = split(" ", $poststatic);
    # set up DNS
    script_run "mkdir -p /etc/systemd/resolved.conf.d";
    assert_script_run 'printf "[Resolve]\nDNSStubListener=no\nDomains=samdom.openqa.fedoraproject.org\nDNS=' . $ip . '\n" > /etc/systemd/resolved.conf.d/sambaad.conf';
    upload_logs "/etc/systemd/resolved.conf.d/sambaad.conf";
    assert_script_run "systemctl restart systemd-resolved.service";
    # deploy the server
    assert_script_run "samba-tool domain provision --server-role=dc --use-rfc2307 --dns-backend=SAMBA_INTERNAL --realm=SAMDOM.OPENQA.FEDORAPROJECT.ORG --domain=samdom --adminpass=129ho3eau47#qm9to9s^", 1200;
    # set up DNS forwarding
    my ($forwarder, $others) = get_host_dns();
    assert_script_run 'sed -i -e "s,dns forwarder =.*,dns forwarder = ' . $forwarder . ',g" /etc/samba/smb.conf';
    upload_logs "/etc/samba/smb.conf";
    # set up kerberos
    assert_script_run "cp /var/lib/samba/private/krb5.conf /etc/krb5.conf.d/samba-dc";
    upload_logs "/etc/krb5.conf.d/samba-dc";
    # enable and start the systemd service
    assert_script_run "systemctl enable samba.service";
    assert_script_run "systemctl start samba.service", 300;

    # kinit as admin
    assert_script_run 'echo "129ho3eau47#qm9to9s^" | kinit administrator';
    # turn off annoying password constraints
    assert_script_run "samba-tool domain passwordsettings set --complexity=off", 1200;
    # set up an OTP for adclient003 enrolment (it will enrol with a kickstart)
    assert_script_run 'echo "129ho3eau47#qm9to9s^" | adcli preset-computer -U administrator --verbose --domain samdom.openqa.fedoraproject.org --stdin-password --one-time-password=monkeys adclient003.samdom.openqa.fedoraproject.org';
    # create two user accounts, test1 and test2
    assert_script_run 'samba-tool user add test1 batterystaple --unix-home=/home/test1 --login-shell=/bin/bash --uid=number=10000 --gid-number=10000';
    # add a rule allowing access to all hosts and services
    #assert_script_run 'ipa hbacrule-add testrule --servicecat=all --hostcat=all';
    # add test1 (but not test2) to the rule
    #assert_script_run 'ipa hbacrule-add-user testrule --users=test1';
    # disable the default 'everyone everywhere' rule
    #assert_script_run 'ipa hbacrule-disable allow_all';
    # allow immediate password changes (as we need to test this)
    #assert_script_run 'ipa pwpolicy-mod --minlife=0';
    # magic voodoo crap to allow reverse DNS client sync to work
    # https://docs.pagure.org/bind-dyndb-ldap/BIND9/SyncPTR.html
    #assert_script_run 'ipa dnszone-mod test.openqa.fedoraproject.org. --allow-sync-ptr=TRUE';
    # check we can kinit as each user
    assert_script_run 'printf "batterystaple" | kinit test1@SAMDOM.OPENQA.FEDORAPROJECT.ORG';
    # we're ready for children to enrol, now
    mutex_create("domain_server_ready");
}


sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
