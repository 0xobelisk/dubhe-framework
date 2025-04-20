#[test_only]
module merak::math_tests {
    use std::debug;
    use merak::merak_math_system;

    #[test]
    public fun test_windows2()  {
        debug::print(&merak_math_system::windows(&vector[1, 2, 3, 4, 5], 2));
        debug::print(&merak_math_system::windows(&vector[1, 2, 3, 4, 5], 3));
        debug::print(&merak_math_system::windows(&vector[1, 2], 2));
    }
}