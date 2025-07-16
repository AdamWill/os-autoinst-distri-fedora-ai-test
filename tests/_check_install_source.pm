use base "anacondatest";
use strict;
use testapi;
use anaconda;
use File::Basename;

sub run {
    my $self = shift;
    my $repourl;
    my $addrepourl;
    if (get_var("MIRRORLIST_GRAPHICAL")) {
        $repourl = get_mirrorlist_url();
    }
    else {
        $repourl = get_var("REPOSITORY_VARIATION", get_var("REPOSITORY_GRAPHICAL"));
        $repourl = get_full_repo($repourl) if ($repourl);
        $addrepourl = get_var("ADD_REPOSITORY_VARIATION");
        $addrepourl = get_full_repo($addrepourl) if ($addrepourl);
    }

    # check that the repo was used
    $self->root_console;
    if ($addrepourl) {
        if ($addrepourl =~ m,^nfs://,,) {
            # this line tells us it set up a repo for our URL.
            assert_script_run 'grep "Add the \'addrepo.*file:///run/install/sources/mount-.000-nfs-device" /tmp/syslog';
            # ...this line tells us it added the repo called 'addrepo'
            assert_script_run 'grep "Added the \'addrepo\'" /tmp/syslog';
            # ...and this tells us it worked (I hope). This is for dnf4
            if (script_run 'grep "Load metadata for the \'addrepo\'" /tmp/syslog') {
                # this is dnf5 - switched in F43, 2025-07
                assert_script_run 'grep "Loading repomd and primary for repo .addrepo." /tmp/dnf.log';
            }
            # dnf4 again
            if (script_run 'grep -E "Loaded metadata from.*file:///run/install/sources/mount-.000-nfs-device" /tmp/syslog') {
                # dnf5
                assert_script_run 'grep "Writing primary cache for repo .addrepo." /tmp/dnf.log';
            }
        }
    }
    if ($repourl =~ /^hd:/) {
        assert_script_run "mount |grep 'fedora_image.iso'";
    }
    elsif ($repourl =~ s/^nfs://) {
        $repourl =~ s/^nfsvers=.://;
        # the above both checks if we're dealing with an NFS URL, and
        # strips the 'nfs:' and 'nfsvers=.:' from it if so
        # remove image.iso name when dealing with nfs iso
        if ($repourl =~ /\.iso/) {
            $repourl = dirname $repourl;
        }
        # check the repo was actually mounted
        assert_script_run "mount |grep nfs |grep '${repourl}'";
    }
    elsif ($repourl) {
        # there are only three hard problems in software development:
        # naming things, cache expiry, off-by-one errors...and quoting
        assert_script_run 'grep "Added the \'anaconda\'" /tmp/anaconda.log /tmp/syslog';
        if (script_run 'grep "Load metadata for the \'anaconda\'" /tmp/anaconda.log /tmp/syslog') {
            # dnf5
            assert_script_run 'grep "Loading repomd and primary for repo .anaconda." /tmp/dnf.log';
        }
        if (script_run 'grep "Loaded metadata from.*' . ${repourl} . '" /tmp/anaconda.log /tmp/syslog') {
            assert_script_run 'grep "Writing primary cache for repo .anaconda." /tmp/dnf.log';
        }
    }
    # just for convenience - sometimes it's useful to see these logs
    # for a success case
    upload_logs "/tmp/packaging.log", failok => 1;
    upload_logs "/tmp/dnf.log", failok => 1;
    upload_logs "/tmp/syslog", failok => 1;
    select_console "tty6-console";

    # Anaconda hub
    assert_screen "anaconda_main_hub", 30;

}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
