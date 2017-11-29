%% This script tries to do all at once!
close all
clear
clc

addpath('tools/');

%% Run basic simulation
dss_master_path = dir('../LVTestCase/Master.dss');
dss_data_dir = dir('../Daily_1min_100profiles/*.txt');

[dss, data] = setup_dss(dss_master_path, '318', dss_data_dir);

% Remove last three elements in data
data = data(:, 1:dss.get_load_count);
data(:, end-2:end) = 0;

% [~, max_idx] = max(sum(data, 2));
% max_idx = max_idx + (0:4);
% data = data(max_idx, :);

[actual_load, actual_voltages] = solve_dss(dss, data);

%% Now 

profile_reps = 100;
idx = dss.get_load_count() - [2 1 0];
ignore_idx = idx;
do_plot = false;

[ rand_profiles ] = match_random_load_and_voltage( ...
profile_reps, actual_load, actual_voltages, idx, dss, ignore_idx, do_plot );

%% Now plot the output
plot(rand_profiles)