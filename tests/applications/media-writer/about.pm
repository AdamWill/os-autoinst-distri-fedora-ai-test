use base "installedtest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    # Start the application
    menu_launch_type("media-writer", checkstart => 1);

    # Click the About Button.
    assert_and_click 'mwriter-about-button';

    # Check to see the information.
    assert_screen 'mwriter-about-dialog';

    # Close the dialogue.
    assert_and_click 'mwriter-about-close';

    # Shut down the application
    send_key("alt-f4");
}

1;
