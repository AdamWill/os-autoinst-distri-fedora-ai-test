package mwriter;

use strict;

use base 'Exporter';
use Exporter;
use lockapi;
use testapi;
use utils;

our @EXPORT = qw(select_edition select_version select_arch confirm_disk_modification check_written_content);


# Selects a Fedora edition in Media Writer by opening the dropdown,
# clicking the given edition, and asserting the selected state.
sub select_edition {
    my $edition = shift;
    assert_and_click("mwriter_dropdown_arrow");
    assert_and_click("mwriter_select_$edition");
    assert_screen("mwriter_selected_$edition");
}

# Selects a Fedora version in Media Writer by opening the version dropdown
# and clicking the specified version entry.
sub select_version {
    my $version = shift;
    assert_and_click("mwriter_dropdown_version");
    assert_and_click("mwriter_select_$version");
}

# Selects a target architecture in Media Writer by opening the architecture
# dropdown and clicking the specified architecture entry.
sub select_arch {
    my $arch = shift;
    assert_and_click("mwriter_dropdown_arch");
    assert_and_click("mwriter_select_$arch");
}

# Validates that the USB media was written correctly.
# Verifies the embedded checksum on the device and compares its contents
# byte-for-byte with the originally downloaded ISO image.
# Assumes the target device is /dev/sda which is correct as the normal
# disk is /dev/vda and the CD mechanics is /dev/sr0
sub check_written_content {
    my $iso = script_output("ls /home/test/Downloads/*.iso");
    my $variant = get_var("SUBVARIANT");
    my $checkiso = "checkisomd5 -v /dev/sda";
    my $compare = "cmp /dev/sda $iso 2>&1 | tee /dev/stderr | grep -q 'EOF on .*\.iso'";

    # Check the checksum of the written media and compare the ISO and the media.
    if ($variant eq "Silverblue") {
        toolbox("run", "$checkiso");
    }
    else {
        assert_script_run("$checkiso", timeout => 300);
    }
    assert_script_run("$compare", timeout => 300);
}



1;
