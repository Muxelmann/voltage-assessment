function [ ss_power, load_voltages ] = solve_dss( dss, data )
%SOLVE_DSS Solves DSS for data and returns power and voltages
%   [p, v] = SOLVE_DSS(dss)
%   [p, v] = SOLVE_DSS(dss, data)
%
%   Here:   `dss` is the DSSClass object
%           `data` is a matrix of load shapes in each column vector
%           `p` is the substation (or transformer) power
%           `v` are all load voltages


if exist('data', 'var') > 0
    dss.set_load_shape(data)
end

dss.reset(); % Resets all monitors and energy-meters
dss.solve(); % Solves the time-series

[pq, ~] = dss.get_monitor_data('txfrmr_mon_'); % Get monitor's data
ss_power = abs(double(cell2mat(arrayfun(@(x) pq.data(:, (x*2)-1+2) + 1j*pq.data(:, (x*2)+2), 1:3, 'uni', 0))));

[~, vi] = dss.get_monitor_data('load_mon_'); % Get monitor's data
load_voltages = double(reshape(cell2mat(arrayfun(@(x) vi(x).data(:, 3), 1:length(vi), 'uni', 0)), [], dss.get_load_count()));

end

