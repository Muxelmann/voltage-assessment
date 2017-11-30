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

if exist('analysis.mat', 'file')
    load analysis.mat
    t_start = mean(sum(all(isnan(t_elapsed) == 0, 3)))+1;
else
    t_elapsed = nan(size(data, 1), 2, 100);
    sim_error = nan(size(data, 1), 2, 100);
    t_start = 1;
end
for n = t_start:size(t_elapsed, 1)
    
    for m = 1:size(t_elapsed, 3)
        ss_power = {};
        load_voltages = {};
        
        tic
        [ ss_power{1}, load_voltages{1} ] = solve_dss(dss, data(1:n, :), false);
        t_elapsed(n, 1, m) = toc;
        
        tic
        [ ss_power{2}, load_voltages{2} ] = solve_dss(dss, data(1:n, :), true);
        t_elapsed(n, 2, m) = toc;
        
        sim_error(n, 1, m) = mean(abs(ss_power{1}(:) - ss_power{2}(:)));
        sim_error(n, 2, m) = mean(abs(load_voltages{1}(:) - load_voltages{2}(:)));
    end
    
    disp([n ...
        mean(t_elapsed(n, :, :), 3) ...
        mean(t_elapsed(n, 1, :), 3)/mean(t_elapsed(n, 2, :), 3) ...
        mean(sim_error(n, :, :), 3) ...
        ]);
    save('analysis.mat', 't_elapsed', 'sim_error');
end

%%

t_start = mean(sum(all(isnan(t_elapsed) == 0, 3)));
t_elapsed = t_elapsed(1:t_start, :, :);

figure(1);
yyaxis left
% errorbar(mean(t_elapsed, 3), std(t_elapsed, [], 3), 'CapSize', 1);
h = plot(mean(t_elapsed, 3));
hold on
for i = 1:length(h)
    fill([1:t_start, t_start:-1:1], ...
        [mean(t_elapsed(:, i, :), 3) + std(t_elapsed(:, i, :), [], 3); ...
        mean(t_elapsed(t_start:-1:1, i, :), 3) - std(t_elapsed(t_start:-1:1, i, :), [], 3)],...
         h(i).Color, 'LineStyle', 'none', 'FaceAlpha', 0.3);
end
hold off
yyaxis right
r_std = std(t_elapsed(:, 1, :), [], 3) + std(t_elapsed(:, 2, :), [], 3);
r_max = max(t_elapsed(:, 1, :) ./ t_elapsed(:, 2, :), [], 3);
r_min = min(t_elapsed(:, 1, :) ./ t_elapsed(:, 2, :), [], 3);
r = mean(t_elapsed(:, 1, :) ./ t_elapsed(:, 2, :), 3);
h = plot(r);
hold on
    fill([1:t_start, t_start:-1:1], ...
        [r+r_std; r(t_start:-1:1)-r_std(t_start:-1:1)],...
         h.Color, 'LineStyle', 'none', 'FaceAlpha', 0.3);
hold off
