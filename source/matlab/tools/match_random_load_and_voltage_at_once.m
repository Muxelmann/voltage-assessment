function [ rand_profiles ] = match_random_load_and_voltage_at_once( ...
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
phase_count = size(load_location, 2);
zone_count = size(load_location, 3);

rand_profiles_pass = zeros(length(rand_profiles), 1);

for n = 1:length(rand_profiles)
    if rand_profiles_pass(n) == 1
        continue
    end
    
    % Get the load profile for each repetition
    rand_profile = rand_profiles{n};
    
    x0 = ones(1, size(rand_profile, 1) * phase_count * zone_count);
    
    % Define fmincon parameters
    A = [];
    b = [];
    Aeq = []; %repmat(eye(phase_count), 1, zone_count);
    beq = []; %ones(phase_count, 1);
    lb = 1e-4 * ones(size(x0));
    ub = 1e+1 * ones(size(x0));
    
    fmincon_opt = optimoptions(@fmincon);
    % fmincon_opt.Algorithm = 'sqp';
    if do_plot
        fmincon_opt.PlotFcns = {@optimplotx, @optimplotfval};
    else
        fmincon_opt.OutputFcn = @progress_callback;
    end
    fmincon_opt.OptimalityTolerance = 1e-4;
    fmincon_opt.Display = 'none';
    fmincon_opt.FiniteDifferenceStepSize = 1e-3;
    fmincon_opt.MaxIterations = 2.5e3;
    fmincon_opt.MaxFunctionEvaluations = 7.5e3;
    
    fprintf('starting: %5d of %5d\n', n, length(rand_profiles));
    
    print_string = '';
    t_start = now * 60*60*24;
    [rand_load_adj, fval, exitflag] = fmincon(@(x) cost_vp_offset(x, rand_profile, dss, actual_load, actual_voltages, idx), ...
        x0, A, b, Aeq, beq, lb, ub, [], fmincon_opt);
    
    % Check whether the solver exited correctly
    assert(exitflag > 0);
    
    % [ cost_final, p_final, v_final ] = cost_vp_offset(rand_load_adj, rand_profiles_t, dss, actual_load_t, actual_voltages_t, idx);
    rand_profile = adjust_load_shapes(rand_load_adj, rand_profile, dss);
    
    t_elapsed = now * 60*60*24 - t_start;
    fprintf(' -> took %.2fs with %f error\n', t_elapsed, fval);

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

    function stop = progress_callback(~, optimValues, ~)
        t_elapsed = now * 60*60*24 - t_start;
        fprintf(repmat('\b', 1, length(print_string)));
        print_string = sprintf('-> iteration: %d, cost: %.2f, time elapsed: %.2fs\n', ...
            optimValues.iteration, optimValues.fval, t_elapsed);
        fprintf(print_string)
        stop = false;
    end

end