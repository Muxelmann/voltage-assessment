function [ cost ] = cost_voltage_offset(phase_percent, loads, loads_location, dss, voltages, idx )
%COST_VOLTAGE_OFFSET Summary of this function goes here
%   Detailed explanation goes here

adj_load = adjust_load_shapes(phase_percent, loads, loads_location);

dss.set_load_shape(adj_load);
dss.reset();
dss.solve();

[~, vi] = dss.get_monitor_data('load_mon_');
v_sim = cell2mat(arrayfun(@(x) x.data(:, 3), vi, 'uni', 0));

cost = double(max(abs(v_sim(:, idx) - voltages(:, idx)), [], 2));



end

