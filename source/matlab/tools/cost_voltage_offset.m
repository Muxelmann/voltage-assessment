function [ cost ] = cost_voltage_offset(loads_scaling, loads_original, dss, voltages, idx )
%COST_VOLTAGE_OFFSET Summary of this function goes here
%   Detailed explanation goes here

loads_new = adjust_load_shapes(loads_scaling, loads_original, dss);
[~, v_sim] = solve_dss(dss, loads_new);

cost = sum(abs(v_sim(:, idx) - voltages(:, idx)), 2);

end

