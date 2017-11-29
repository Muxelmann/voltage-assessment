function [ cost, p_sim, v_sim ] = cost_vp_offset(loads_scaling, loads_original, dss, actual_load, actual_voltages, idx )
%COST_VOLTAGE_OFFSET Summary of this function goes here
%   Detailed explanation goes here

loads_new = adjust_load_shapes(loads_scaling, loads_original, dss);
[p_sim, v_sim] = solve_dss(dss, loads_new);

cost = ...
    sum(abs(v_sim(:, idx) - actual_voltages(:, idx)), 2) + ...
    sum(abs(p_sim - actual_load), 2);

end

