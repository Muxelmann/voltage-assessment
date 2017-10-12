close all
clear

fprintf('\n\n---- START ----\n');

addpath('tools/');

%% Run basic simulation
dss_master_path = dir('../LVTestCase/Master.dss');
dss_data_dir = dir('../Daily_1min_100profiles/*.txt');

[dss, data] = setup_dss(dss_master_path, '318', dss_data_dir);

% Remove last three elements in data
data = data(:, 1:dss.get_load_count);
data(1, end-2:end) = 0;

[~, max_idx] = max(sum(data, 2));
data = data(max_idx, :);
clear max_idx;

[actual_load, actual_voltages] = solve_dss(dss, data);

%% Generate random loads that has the same power profile n times

profile_reps = 10; % Define the number of profile repetitions
[rand_load, i_remain] = match_random_load(profile_reps, actual_load, dss, true);

assert(i_remain > 0)
clear i_remain

save tmp_p

%% Match random loads to voltages

idx = dss.get_load_count() - [2 1 0]; % Voltages that should be matched
rand_load_final = match_random_voltage(rand_load, actual_voltages, idx, dss);

save tmp_v

%% Test how well the solution converged

test_pass = convergence_test(rand_load_final, actual_load, actual_voltages, idx, dss);

% I found that when scaling down loads within a load zone, they do actually
% reach zero at some stage and cannot recover. This leads to a discrepancy
% in the demand profile and causes the solution not to converge (maybe).
% 
% Consider using two scaling mechanisms for the random load profiles:
% 1. proportional:  where the loads are scaled up and down based on their
%                   relative contribution to the overall profile
% 2. uniformly:     where the loads are scaled equally regardless of their
%                   relative contribution to the overall profile
%
% By implementing the 2. scaling, zero loads (apart from ESMU) can be
% re-included into the solving mechanism.

while any(test_pass == 0)
    if all(test_pass == 0)
        disp('Everything needs to be re-evaluated');
    elseif any(test_pass == 0)
        disp([num2str(sum(test_pass == 0)) ' simulations need to be re-evaluated']);
    else
        disp('Nothing needs to be re-evaluated');
    end
    
    [rand_load_corrected, i_remain] = match_random_load({rand_load_final(test_pass == 0, :)}, actual_load, dss, true);

    assert(i_remain > 0)
    clear i_remain

    rand_load_final(test_pass == 0, :) = match_random_voltage(rand_load_corrected, actual_voltages, idx, dss);
    
    test_pass = convergence_test(rand_load_final, actual_load, actual_voltages, idx, dss);
end

save tmp_c
