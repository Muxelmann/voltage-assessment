clear
clc

load tmp_withLS.mat

cmp = [];
cmp(1).load_voltages = load_voltages;
cmp(1).ss_power = ss_power;
cmp(1).t_elapsed = t_elapsed;

load tmp_withoutLS.mat

cmp(2).load_voltages = load_voltages;
cmp(2).ss_power = ss_power;
cmp(2).t_elapsed = t_elapsed;

figure(1)
plot(cmp(1).load_voltages(:, 2))
hold on
plot(cmp(2).load_voltages(:, 2))
hold off

%% This part analyses the simulation time sensitivity
close all
clear
clc

addpath('tools/');

dss_master_path = dir('../LVTestCase/Master.dss');
dss_data_dir = dir('../Daily_1min_100profiles/*.txt');

[dss, data] = setup_dss(dss_master_path, '318', dss_data_dir);

% Remove last three elements in data
data = data(:, 1:dss.get_load_count);
data(:, end-2:end) = 0;

t_elapsed = nan(size(data, 1), 2, 100);
for n = 1:size(t_elapsed, 1)
    
    for m = 1:size(t_elapsed, 3)
        tic
        solve_dss(dss, data(1:n, :), false);
        t_elapsed(n, 1, m) = toc;
        
        tic
        solve_dss(dss, data(1:n, :), true);
        t_elapsed(n, 2, m) = toc;
    end
    
    disp([n mean(t_elapsed(n, :, :), 3) mean(t_elapsed(n, 1, :), 3)/mean(t_elapsed(n, 2, :), 3)]);
    save('analysis.mat', 't_elapsed');
end
