close all
clear

%% Run basic simulation
dss_master_path = dir('LVTestCase/Master.dss');
dss_data_dir = dir('Daily_1min_100profiles/*.txt');
data = [];
for i = 1:length(dss_data_dir)
    data_new = csvread(fullfile(dss_data_dir(i).folder, dss_data_dir(i).name));
    data = [data, data_new];
end

dss = DSSClass(fullfile(dss_master_path.folder, dss_master_path.name));
dss.set_load_shape(data);

% Add ESMU
dss.put_esmu_at_bus('318');
[load_zones] = dss.get_load_meters();
[load_phases] = dss.get_load_phases();

% dss.down_stream_customers();

[load_distances, load_names] = dss.get_load_distances();
plot(load_distances, 'x');
hold on
arrayfun(@(x) text(x, load_distances(x), load_names{x}, 'Rotation', -60), 1:length(load_distances));
hold off

%%
dss.reset(); % Resets all monitors and energy-meters
dss.solve(); % Solves the time-series
[pq, vi] = dss.get_monitor_data(); % Get monitor's data

actual_load = double(cell2mat(arrayfun(@(x) abs(x.data(:,3:4) * [1; 1j]), pq, 'uni', 0)));
actual_load = cell2mat(arrayfun(@(x) sum(actual_load(:, load_phases == x), 2), 1:3, 'uni', 0));

actual_voltages = double(reshape(cell2mat(arrayfun(@(x) vi(x).data(:, 3), 1:length(vi), 'uni', 0)), [], dss.get_load_count()));

figure(1);
yyaxis left
plot((1:1440)/60, actual_load)

yyaxis right
plot((1:1440)/60, mean(actual_voltages, 2));
ylabel('power (kVA)');
xlabel('time (h)');
hold on
plot((1:1440)/60, max(actual_voltages, [], 2));
plot((1:1440)/60, min(actual_voltages, [], 2));
hold off
ylabel('voltage (V)');
drawnow

%% Generate random loads that have the same power profile n times

profile_reps = 2; % Define the number of profile repetitions

rand_load = {[...
    rand(size(actual_load, 1) * profile_reps, dss.get_load_count() - 3)...
    zeros(size(actual_load, 1) * profile_reps, 3) ...
    ]};

rand_load_scale = cell2mat(arrayfun(@(x) repmat(actual_load(:, x), profile_reps, 1) ./ sum(rand_load{end}(:, load_phases == x), 2), 1:3, 'uni', 0));
for p = 1:3
    rand_load{end}(:, load_phases == p) = rand_load{end}(:, load_phases == p) .* rand_load_scale(:, p);
end

i_max = 10; % Stop after `i_max` iterations
t_reps = (1:size(rand_load{end}, 1)) / 60;
while true
    % run this random profile
    dss.set_load_shape(rand_load{end});
    dss.solve();
    
    [pq_rand, vi_rand] = dss.get_monitor_data();
    
    % Calculate the error from running this random profile
    rand_load_result = cell2mat(arrayfun(@(x) abs(pq_rand(x).data(:,3:4) * [1; 1j]), 1:length(pq_rand), 'uni', 0));
    rand_load_result = cell2mat(arrayfun(@(x) sum(rand_load_result(:, load_phases == x), 2), 1:3, 'uni', 0));
    
    rand_load_error_total = rand_load_result - repmat(actual_load, profile_reps, 1);
    e_mean = mean(rand_load_error_total);
    e_std = std(rand_load_error_total);
    
    figure(2);
    plot(t_reps, rand_load_error_total);
    ax = gca;
    hold on
    line(ax.XLim, ones(2,1) * e_mean, 'Color', 'r');
    line(ax.XLim, ones(2,1) * e_mean+e_std, 'Color', 'r', 'LineStyle', '--');
    line(ax.XLim, ones(2,1) * e_mean-e_std, 'Color', 'r', 'LineStyle', '--');
    hold off
    xlabel('time (h)');
    ylabel('power error (kVA)');
    title(['mean: ' num2str(e_mean) ' | std: ' num2str(e_std)]);
    drawnow
    
    i_max = i_max - 1;
    
    if i_max < 0 || (all(round(abs(e_mean+e_std)*1000) == 0) && all(round(abs(e_mean-e_std)*1000) == 0))
        break
    end
    
    rand_load_next = nan(size(rand_load{end}));
    for p = 1:3
        rand_load_next(:, load_phases == p) = rand_load{end}(:, load_phases == p) - rand_load_error_total(:, p) .* rand_load{end}(:, load_phases == p) ./ sum(rand_load{end}(:, load_phases == p), 2);
    end
    rand_load{end+1} = rand_load_next;
end

return
%% Now do the voltage assessment

% Calculate voltages
rand_voltages = double(reshape(cell2mat(arrayfun(@(x) vi_rand(x).data(:, 3), 1:length(vi_rand), 'uni', 0)), [], dss.get_load_count()));
boxplot(reshape(rand_voltages, [], dss.get_load_count()));

rand_voltages_error = rand_voltages(:, end-2:end) - repmat(actual_voltages(:, end-2:end), profile_reps, 1);

rand_load_final = double(rand_load{end});

% For each phase
for p = 1:3
    rand_voltages_phase_error = rand_voltages_error(:, p) ./ repmat(actual_voltages(:, end-3+p), profile_reps, 1);
    loads_up_stream = load_zones == 1 & load_phases == p;
    loads_down_stream = load_zones == 2 & load_phases == p;
    
    rand_load_up_stream = sum(rand_load_final(:, loads_up_stream), 2);
    rand_load_down_stream = sum(rand_load_final(:, loads_down_stream), 2);
    
    rand_load_down_ratio = rand_load_up_stream ./ rand_load_down_stream;
    
    load_shuffle_up = rand_load_down_ratio .* rand_voltages_phase_error .* rand_load_final(:, loads_down_stream);
    
end

return
%% Get distance to node

[load_distances, load_names] = dss.get_load_distances();
plot(load_distances);
% plot(load_distances, squeeze(voltages(1, 1, :)), 'x');
% hold on
% arrayfun(@(x) text(load_distances(x), voltages(1, 1, x), load_names{x}), 1:length(load_names));
% hold off



%% Stop here
return
