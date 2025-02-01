use base "installedtest";
use strict;
use testapi;
use utils;


sub run {
    my $self = shift;
    $self->root_console(tty => 3);
    # on non-canned flavors, we need to install toolbox
    assert_script_run "dnf -y install toolbox", 360 unless (get_var("CANNED"));
    # check toolbox is installed
    assert_script_run "rpm -q toolbox";
    # check to see if you can create a new toolbox container (this
    # will download the 'current' image for the same release and use
    # that; we want to check that works even if we will go on to test
    # an image from the compose below)
    assert_script_run "toolbox create container1 -y", 300;
    my $image = get_var("TOOLBOX_IMAGE");
    if ($image) {
        # we have a toolbox image to test in the item under test
        # (probably a compose), so let's recreate container1 using
        # that instead
        my $relnum = get_release_number;
        assert_script_run 'toolbox rm container1';
        assert_script_run "toolbox rmi containers-storage:registry.fedoraproject.org/fedora-toolbox:$relnum";
        assert_script_run "curl -o /var/tmp/toolbox.tar.gz $image", 300;
        # this registers the downloaded image such that `toolbox create`
        # will use it, rather than downloading one. it takes a while
        my $format = $image =~ "oci" ? "oci-archive" : "docker-archive";
        assert_script_run "skopeo copy $format:/var/tmp/toolbox.tar.gz containers-storage:registry.fedoraproject.org/fedora-toolbox:$relnum", 600;
        # we do not pass -y this time as we do not want to allow a
        # download, if toolbox wants to do one, something has gone
        # wrong. unfortunately there is no -n so we just have to let
        # it time out in that case
        assert_script_run "toolbox create container1", 60;
    }
    # check to see if toolbox can list container
    assert_script_run "toolbox list | grep container1";
    # run a specific command on a given container, note as of 2024-10
    # the output changed from "Linux toolbox" to "Linux toolbx"
    validate_script_output "toolbox run --container container1 uname -a", sub { m/Linux toolbo?x/ };
    # enter container to test
    type_string "toolbox enter container1\n";
    # holds on to the screen
    assert_screen "console_in_toolbox", 180;
    # exits toolbox container
    type_string "exit\n";
    sleep 3;
    assert_script_run "clear";
    # Stop a container
    assert_script_run 'podman stop container1';
    # Toolbox remove container
    assert_script_run "toolbox rm container1";
    # Toolbox remove image and their associated containers
    assert_script_run "toolbox rmi --all --force";
    # create a rhel image with distro and release flags
    assert_script_run "toolbox -y create --distro rhel --release 9.5", 300;
    # validate rhel release file to ensure correct version
    type_string "toolbox enter rhel-toolbox-9.5\n";
    assert_screen "console_in_toolbox", 180;
    type_string "exit\n";
    sleep 3;
    #run a specific command on a given choice of distro and release
    validate_script_output "toolbox run --distro rhel --release 9.5 cat /etc/redhat-release", sub { m/Red Hat Enterprise Linux release 9.5 \(Plow\)/ };


}


sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et
