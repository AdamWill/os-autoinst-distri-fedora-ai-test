use base "installedtest";
use strict;
use testapi;
use utils;

# This script checks that Gnome Calculator
# can use pre-selected functions.

sub use_function {
    my $function = shift;
    assert_and_click("calc_button_fxunified");
    send_key_until_needlematch("calc_function_$function", "down", 50);
    click_lastmatch();
    assert_and_click("calc_button_five");
    send_key("ret");
    assert_screen("calc_result_$function");
    assert_and_click("calc_button_clear");
}

sub run {
    my $self = shift;
    # Wait until everything settles.
    sleep 5;

    use_function("sqrt");
    use_function("arg");
    use_function("cos");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:

