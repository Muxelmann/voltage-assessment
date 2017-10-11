close all
clear

addpath('tools/');

%% Run basic simulation
dss_master_path = dir('../LVTestCase/Master.dss');
dss_data_dir = dir('../Daily_1min_100profiles/*.txt');

[dss, data] = setup_dss(dss_master_path, '318', dss_data_dir);

% Remove last three elements in data
data = data(1, 1:dss.get_load_count);
data(1, end-2:end) = 0;

[actual_load, actual_voltages] = solve_dss(dss, data);

% figure(1);
% yyaxis left
% plot((1:size(data, 1))/60, actual_load)
% 
% yyaxis right
% plot((1:size(data, 1))/60, mean(actual_voltages, 2));
% ylabel('power (kVA)');
% xlabel('time (h)');
% hold on
% plot((1:size(data, 1))/60, max(actual_voltages, [], 2));
% plot((1:size(data, 1))/60, min(actual_voltages, [], 2));
% hold off
% ylabel('voltage (V)');
% drawnow

%% Generate random loads that has the same power profile n times
profile_reps = 10; % Define the number of profile repetitions
[ rand_load ] = match_random_load( profile_reps, actual_load, dss, true );

save tmp

%% Match random loads to voltages

idx = dss.get_load_count() - [2 1 0]; % Voltages that should be matched
[ rand_load_v ] = match_random_voltage( rand_load, actual_voltages, idx, dss );

