function [ rand_load_next ] = match_random_voltage( rand_load, actual_voltages, idx, dss )
%MATCH_RANDOM_VOLTAGE Summary of this function goes here
%   Detailed explanation goes here

load_location = dss.get_load_location(true);

% Define fmincon parameters
A = [];
b = [];
Aeq = repmat(eye(size(load_location, 2)), 1, size(load_location, 3));
beq = ones(size(load_location, 2), 1);
lb = zeros(1, size(load_location, 2) * size(load_location, 3));
ub = ones(1, size(load_location, 2) * size(load_location, 3));

x0 = ones(1, size(load_location, 2) * size(load_location, 3)) * 0.5;

fmincon_opt = optimoptions(@fmincon);
fmincon_opt.PlotFcns = {@optimplotx, @optimplotfval};
fmincon_opt.OptimalityTolerance = 1e-4;
fmincon_opt.Display = 'none';
fmincon_opt.FiniteDifferenceStepSize = 1e-3;

rand_load_next = rand_load{end};
adjust_tol = 1e5;
for t = 1:size(rand_load_next, 1)
    fprintf('starting: %5d', t);
    rand_load_t = rand_load_next(t, :);
    t_actual = mod(t-1, size(actual_voltages, 1)) + 1;
    v_actual = actual_voltages(t_actual, :);
    [rand_load_adj, ~, exitflag] = fmincon(@(x) cost_voltage_offset(x, rand_load_t, dss, v_actual, idx), ...
        x0, A, b, Aeq, beq, lb, ub, [], fmincon_opt);
    
    % Check that the solver exited correctly
    assert(exitflag > 0);
    % Make sure all loads are balanced
    assert(all(round(sum(reshape(rand_load_adj, size(load_location, 2), size(load_location, 3)), 2) * adjust_tol) == adjust_tol));
    
    rand_load_next(t, :) = adjust_load_shapes(rand_load_adj, rand_load_t, dss);
    fprintf(' -> DONE\n');
end

end

