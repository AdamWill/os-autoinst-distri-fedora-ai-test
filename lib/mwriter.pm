package mwriter;

use strict;

use base 'Exporter';
use Exporter;
use lockapi;
use testapi;
use utils;

our @EXPORT = qw(check_written_content);


# Validates that the USB media was written correctly.
# Verifies the embedded checksum on the device and compares its contents
# byte-for-byte with the originally downloaded ISO image.
# Assumes the target device is /dev/sda which is correct as the normal
# disk is /dev/vda and the CD mechanics is /dev/sr0
sub check_written_content {
    my $iso = script_output("ls -t /home/test/Downloads/*.iso | head -n1");
    my $variant = get_var("SUBVARIANT");
    my $checkiso = "checkisomd5 -v /dev/sda";
    my $compare = "cmp /dev/sda \"$iso\" 2>&1 | tee /dev/stderr | grep -q 'EOF on .*\.iso'";

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
