function [ test_pass ] = convergence_test( data, actual_load, actual_voltages, idx, dss )
%TEST_CONVERGENCE Summary of this function goes here
%   Detailed explanation goes here

[ss_power, load_voltages] = solve_dss(dss, data);

load_error = ss_power - actual_load;
voltage_error = load_voltages(:, idx) - actual_voltages(:, idx);

test_pass = all(abs(voltage_error(:)) < 0.1) & all(abs(load_error(:)) < 1e-3);

end

