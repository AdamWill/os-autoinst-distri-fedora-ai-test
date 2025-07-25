use base "installedtest";
use strict;
use lockapi;
use mmapi;
use tapnet;
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->root_console(tty => 3);
    # on non-canned flavors, we need to install podman, may as well
    # also install the tests now

    # check podman is installed

    my $relnum = get_release_number;
    if (get_var("CANNED")) {
        # check podman is pre-installed
        assert_script_run "rpm -q podman";
    }
    else {
        # install podman and run the upstream integration tests
        assert_script_run "dnf -y install podman podman-tests bats", 600;
        # podman system tests use a relative path for podman-testing by default,
        # we need to set it to the location where the podman-tests package installs it.
        assert_script_run 'export PODMAN_TESTING=/usr/bin/podman-testing';
        # load null_blk module which is needed for "podman run --device-read-bps" test case:
        # https://github.com/containers/podman/pull/26022
        assert_script_run 'modprobe null_blk nr_devices=1';
        # needed so we exit 1 when the bats command fails
        assert_script_run "set -o pipefail";
        assert_script_run "bats --filter-tags distro-integration /usr/share/podman/test/system | tee /tmp/podman-bats.txt", 600;
        # restore default behaviour
        assert_script_run "set +o pipefail";
    }
    # check to see if you can pull an image from the registry
    assert_script_run "podman pull registry.fedoraproject.org/fedora:latest", 300;
    # run hello-world to test
    validate_script_output "podman run -it registry.fedoraproject.org/fedora:latest echo Hello-World", sub { m/Hello-World/ };
    # create a Containerfile
    assert_script_run 'printf \'FROM registry.fedoraproject.org/fedora:latest\nRUN /usr/bin/dnf install -y httpd\nEXPOSE 80\nCMD ["-D", "FOREGROUND"]\nENTRYPOINT ["/usr/sbin/httpd"]\n\' > Containerfile';
    # Build an image
    assert_script_run 'podman build -t fedora-httpd $(pwd)', 180;
    # Verify the image
    validate_script_output "podman images", sub { m/fedora-httpd/ };
    # Run the container
    assert_script_run "podman run -d -p 80:80 localhost/fedora-httpd";
    # Verify the container is running
    validate_script_output "podman container ls", sub { m/fedora-httpd/ };
    # Test apache is working
    assert_script_run "curl http://localhost";
    # Open the firewall, except on CoreOS where it's not installed
    unless (get_var("SUBVARIANT") eq "CoreOS") {
        assert_script_run "firewall-cmd --permanent --zone=internal --add-interface=cni-podman0";
        assert_script_run "firewall-cmd --permanent --zone=internal --add-port=80/tcp";
    }
    # tell client we're ready and wait for it to send the message
    mutex_create("podman_server_ready");
    my $children = get_children();
    my $child_id = (keys %$children)[0];
    mutex_lock("podman_connect_done", $child_id);
    mutex_unlock("podman_connect_done");
}


sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
