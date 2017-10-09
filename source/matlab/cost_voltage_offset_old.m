function [ cost, load_data_scaled, v_sim ] = cost_voltage_offset_old( scale, load_data, loads_location, dss, voltages, idx )

% Adjust load_data and scale down

% Make sure load_data is only 1 time step
assert(size(load_data, 1) == 1)

% for each phase, scale down the "down stream load"
load_data_scaled = nan(size(load_data));
for p = 1:3
    load_down_delta = scale(p) .* load_data(:, loads_location(:, p, 2));
    load_data_scaled(:, loads_location(:, p, 2)) = load_data(:, loads_location(:, p, 2)) - load_down_delta;
    
    load_up_scale = 1 + sum(load_down_delta, 2) ./ sum(load_data(:, loads_location(:, p, 1)));
    load_data_scaled(:, loads_location(:, p, 1)) = load_up_scale .* load_data(:, loads_location(:, p, 1));
end


% Simulate and determine cost
dss.set_load_shape(repmat(load_data_scaled, 1, 1));
dss.reset();
dss.solve();

[~, vi] = dss.get_monitor_data();
v_sim = double(reshape(cell2mat(arrayfun(@(x) vi(x).data(:, 3), 1:length(vi), 'uni', 0)), [], dss.get_load_count()));

cost = sum(abs(v_sim(:, idx) - voltages(:, idx)), 2);
end

