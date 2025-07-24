use base "installedtest";
use strict;
use lockapi;
use mmapi;
use tapnet;
use testapi;
use utils;

sub run_integration_tests {
    # run the upstream integration tests
    # podman system tests use a relative path for podman-testing by default,
    # we need to set it to the location where the podman-tests package installs it.
    assert_script_run 'export PODMAN_TESTING=/usr/bin/podman-testing';
    # needed so we exit 1 when the bats command fails
    assert_script_run "set -o pipefail";
    # skips:
    # "podman checkpoint --export, with volumes"
    # fails on kernel 6.16, see https://github.com/checkpoint-restore/criu/issues/2626
    assert_script_run "bats --filter-tags '!ci:parallel' --filter ', with volumes' /usr/share/podman/test/system | tee /tmp/podman-bats.txt", 900;
    assert_script_run 'bats --filter-tags ci:parallel --filter ", with volumes" -j $(nproc) /usr/share/podman/test/system | tee --append /tmp/podman-bats.txt', 900;
    # restore default behaviour
    assert_script_run "set +o pipefail";
    # ensure we ran at least 100 tests (this is a check that the
    # filter stuff didn't go haywire)
    assert_script_run 'grep "^ok 100" /tmp/podman-bats.txt';
}

sub run {
    my $self = shift;
    $self->root_console(tty => 3);
    my $relnum = get_release_number;
    if (get_var("CANNED")) {
        # check podman is pre-installed
        assert_script_run "rpm -q podman";
    }
    else {
        # install podman and the upstream integration tests
        assert_script_run "dnf -y install podman podman-tests bats", 600;
        # load null_blk module which is needed for "podman run --device-read-bps" test case:
        # https://github.com/containers/podman/pull/26022
        assert_script_run 'modprobe null_blk nr_devices=1';
        # silly hack that inverts the behaviour of bats' --filter -
        # needed until https://github.com/bats-core/bats-core/pull/1114
        # is merged or backported
        assert_script_run 'sed -i -e \'s,! \[\[ "$description" =~ $filter \]\],\[\[ "$description" =~ $filter \]\],g\' /usr/libexec/bats-core/bats-gather-tests';
        # run the integration tests with root on x86_64
        run_integration_tests if (get_var("ARCH") eq "x86_64");
    }
    # Open the firewall, except on CoreOS where it's not installed
    unless (get_var("SUBVARIANT") eq "CoreOS") {
        assert_script_run "firewall-cmd --add-port=8080/tcp";
    }
    # create a non-root user to check rootless operation
    assert_script_run "useradd testman";
    assert_script_run("echo 'testman:weakpassword' | chpasswd");
    # let it write to the serial port
    assert_script_run "chmod 666 /dev/${serialdev}";
    if (script_run "grep testman /etc/subuid") {
        # workaround https://bugzilla.redhat.com/show_bug.cgi?id=2334165#c2
        assert_script_run("usermod --add-subuids 100000-165535 testman");
        assert_script_run("usermod --add-subgids 100000-165535 testman");
    }
    # login as the non-root user
    select_console "tty4-console";
    console_login(user => "testman", password => "weakpassword");
    # run integration tests rootless on other arches
    # neat way to get the tests run both rootful and rootless
    # without causing too much load
    run_integration_tests unless (get_var("CANNED") || get_var("ARCH") eq "x86_64");
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
    assert_script_run "podman run -d -p 8080:80 localhost/fedora-httpd";
    # Verify the container is running
    validate_script_output "podman container ls", sub { m/fedora-httpd/ };
    # Test apache is working
    assert_script_run "curl http://localhost:8080";
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
