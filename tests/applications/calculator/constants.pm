use base "installedtest";
use strict;
use testapi;
use utils;

# This script checks that Gnome Calculator
# can use pre-selected constants.


sub run {
    my $self = shift;
    # Wait until everything settles.
    sleep 5;

    # Check that upper index can be used
    assert_and_click("calc_button_four");
    assert_and_click("calc_button_upper");
    assert_and_click("calc_button_two");
    assert_and_click("calc_button_equals");
    assert_screen("calc_result_sixteen");
    assert_and_click("calc_button_clear");

    # Check that lower index works
    # I cannot think of a math expression that would use
    # subscripts, so let's just check the button works.
    assert_and_click("calc_button_four");
    assert_and_click("calc_button_lower");
    assert_and_click("calc_button_four");
    assert_screen("calc_result_foursub");
    assert_and_click("calc_button_clear");

    # This will check the unified buttons that
    # represents various mathematical expressions.
    # We will only check a couple of them.
    #
    # Pi:
    assert_and_click("calc_button_one");
    assert_and_click("calc_button_xunified");
    assert_and_click("calc_umenu_mathematical");
    assert_and_click("calc_umenu_pi");
    send_key("ret");
    assert_screen("calc_result_314");
    assert_and_click("calc_button_clear");

    # Lightspeed
    assert_and_click("calc_button_one");
    assert_and_click("calc_button_multi");
    assert_and_click("calc_button_xunified");
    assert_and_click("calc_umenu_electromagnetic");
    assert_and_click("calc_umenu_lightspeed");
    send_key("ret");
    assert_screen("calc_result_2997");
    assert_and_click("calc_button_clear");

    # Electron mass
    assert_and_click("calc_button_one");
    assert_and_click("calc_button_xunified");
    assert_and_click("calc_umenu_atomic");
    assert_and_click("calc_umenu_electronmass");
    send_key("ret");
    assert_screen("calc_result_9109");
    assert_and_click("calc_button_clear");

    # Avogadro
    assert_and_click("calc_button_one");
    assert_and_click("calc_button_xunified");
    assert_and_click("calc_umenu_thermo");
    assert_and_click("calc_umenu_avogadro");
    send_key("ret");
    assert_screen("calc_result_6022");
    assert_and_click("calc_button_clear");

    # Earth acceleration
    assert_and_click("calc_button_one");
    assert_and_click("calc_button_xunified");
    assert_and_click("calc_umenu_gravitation");
    assert_and_click("calc_umenu_acceleration");
    send_key("ret");
    assert_screen("calc_result_9806");
    assert_and_click("calc_button_clear");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:

