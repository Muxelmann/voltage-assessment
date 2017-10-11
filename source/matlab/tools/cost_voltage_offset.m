function [ cost ] = cost_voltage_offset(load_proportion, loads, dss, voltages, idx )
%COST_VOLTAGE_OFFSET Summary of this function goes here
%   Detailed explanation goes here

adj_load = adjust_load_shapes(load_proportion, loads, dss);
[~, v_sim] = solve_dss(dss, adj_load);

cost = sum(abs(v_sim(:, idx) - voltages(:, idx)), 2);

end

