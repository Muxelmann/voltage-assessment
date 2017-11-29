function [ test_pass ] = convergence_test( random_profiles, actual_load, actual_voltages, idx, dss )
%TEST_CONVERGENCE Checks if the results from `random_profiles` match

[ss_power, load_voltages] = solve_dss(dss, random_profiles);

load_error = ss_power - actual_load;
voltage_error = load_voltages(:, idx) - actual_voltages(:, idx);

test_pass = all(abs(voltage_error) < 1, 2) & all(abs(load_error) < 1, 2);

end

