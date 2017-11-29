function [ rand_profiles ] = match_random_load_and_voltage( ...
profile_reps, actual_load, actual_voltages, idx, dss, ignore_idx, do_plot )
%MATCH_RANDOM_VOLTAGE Matches both voltages and 

if exist('ignore_idx', 'var') == 0
    ignore_idx = idx;
end

if exist('do_plot', 'var') == 0
    do_plot = false;
end

% Make random profiles
rand_profiles = arrayfun(@(x) make_random_profile(actual_load, dss, ignore_idx), 1:profile_reps, 'uni', 0);

load_location = dss.get_load_location(true);

% Define fmincon parameters
A = [];
b = [];
Aeq = []; %repmat(eye(size(load_location, 2)), 1, size(load_location, 3));
beq = []; %ones(size(load_location, 2), 1);
lb = 0.001 * ones(1, size(load_location, 2) * size(load_location, 3));
ub = 2 * ones(1, size(load_location, 2) * size(load_location, 3));

x0 = ones(1, size(load_location, 2) * size(load_location, 3));

fmincon_opt = optimoptions(@fmincon);
% fmincon_opt.Algorithm = 'sqp';
if do_plot
    fmincon_opt.PlotFcns = {@optimplotx, @optimplotfval};
end
fmincon_opt.OptimalityTolerance = 1e-4;
fmincon_opt.Display = 'none';
fmincon_opt.FiniteDifferenceStepSize = 1e-3;
fmincon_opt.MaxIterations = 2.5e3;
fmincon_opt.MaxFunctionEvaluations = 7.5e3;

rand_profiles_pass = zeros(length(rand_profiles), 1);

for n = 1:length(rand_profiles)
    if rand_profiles_pass(n) == 1
        continue
    end
    
    % Get the load profile for each repetition
    rand_profile = rand_profiles{n};
    
    fprintf('starting: %5d of %5d', n, length(rand_profiles));
    print_string = '';
    
    t_final = size(rand_profile, 1);
    tic;
    for t = 1:t_final
        % Get the current load for each time-step
        rand_profile_t = rand_profile(t, :);
        actual_voltages_t = actual_voltages(t, :);
        actual_load_t = actual_load(t, :);
        
        [rand_load_adj, fval, exitflag] = fmincon(@(x) cost_vp_offset(x, rand_profile_t, dss, actual_load_t, actual_voltages_t, idx), ...
            x0, A, b, Aeq, beq, lb, ub, [], fmincon_opt);
        
        % Check whether the solver exited correctly
        assert(exitflag > 0);
    
        % [ cost_final, p_final, v_final ] = cost_vp_offset(rand_load_adj, rand_profiles_t, dss, actual_load_t, actual_voltages_t, idx);
        rand_profile(t, :) = adjust_load_shapes(rand_load_adj, rand_profile_t, dss);
        
        fprintf(repmat('\b', 1, length(print_string)));
        print_string = sprintf(' -> %6.2f%% took %.2fs with %f error\n', 100*t/t_final, toc, fval);
        fprintf('%s', print_string);
    end

    conv_test = convergence_test(rand_profile, actual_load, actual_voltages, idx, dss);
    if all(conv_test)
        rand_profiles{n} = rand_profile;
        rand_profiles_pass(n) = true;
    else
        fprintf('%6.2f%% was ok but it needs to be redone\n', 100 * sum(conv_test) / numel(conv_test));
        rand_profiles{n} = make_random_profile(actual_load, dss, ignore_idx);
    end
    
    save('tmp_all.mat', 'rand_profiles', 'rand_profiles_pass', ...
        'actual_load', 'actual_voltages', 'idx', 'ignore_idx');
end

end