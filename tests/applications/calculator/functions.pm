use base "installedtest";
use strict;
use testapi;
use utils;

# This script checks that Gnome Calculator
# can use pre-selected functions.

sub use_function {
    my ($function, $where, $expression) = @_;
    assert_and_click("calc_button_fxunified");
    assert_and_click("calc_functions_$where");
    assert_and_click("calc_select_function_$function");
    type_safely($expression);
    send_key("ret");
    assert_screen("calc_result_$function");
    assert_and_click("calc_button_clear");
    # Stop for a moment to let the Calculator clean entry field
    sleep(1);
}

sub run {
    my $self = shift;
    # Wait until everything settles.
    sleep(5);

    use_function("cos", "trigonometry", "45");
    use_function("re", "complex", "20");
    use_function("ones", "programming", "5");
    use_function("round", "rounding", "5.55");
    use_function("median", "statistics", "1;2;4;5");
    use_function("sqrt", "sundry", "5");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:

