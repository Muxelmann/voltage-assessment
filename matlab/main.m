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

% % Add ESMU
% dss.put_esmu_at_bus('318');
% [load_zones] = dss.get_load_meters();
% 
% dss.down_stream_customers();
% 
% 
% [load_distances, load_names] = dss.get_load_distances();
% plot(load_distances, 'x');
% hold on
% arrayfun(@(x) text(x, load_distances(x), load_names{x}), 1:length(load_distances));
% hold off

dss.reset(); % Resets all monitors and energy-meters
dss.solve(); % Solves the time-series
[pq, vi] = dss.get_monitor_data(); % Get monitor's data

total_load = double(cell2mat(arrayfun(@(x) abs(x.data(:,3:4) * [1; 1j]), pq, 'uni', 0)));
total_load = sum(total_load, 2);

voltages = double(cell2mat(arrayfun(@(x) x.data(:, 3), vi, 'uni', 0)));

figure(1);
yyaxis left
plot((1:1440)/60, total_load)

yyaxis right
plot((1:1440)/60, mean(voltages, 2));
ylabel('power (kVA)');
xlabel('time (h)');
hold on
plot((1:1440)/60, max(voltages, [], 2));
plot((1:1440)/60, min(voltages, [], 2));
hold off
ylabel('voltage (V)');
drawnow

%% Generate random loads that have the same power profile n times

profile_reps = 2; % Define the number of profile repetitions

data_rand = {rand(length(total_load) * profile_reps, dss.get_load_count())};
data_scale = repmat(total_load, profile_reps, 1) ./ sum(data_rand{end}, 2);
data_rand{end} = data_rand{end} .* data_scale;

i_max = 10; % Stop after `i_max` iterations
t_reps = (1:size(data_rand{end}, 1)) / 60;

close all
while true
    % run this random profile
    dss.set_load_shape(data_rand{end});
    dss.solve();
    
    [pq_rand, vi_rand] = dss.get_monitor_data();
    
    % Calculate the error from running this random profile
    data_rand_result = sum(cell2mat(arrayfun(@(x) abs(pq_rand(x).data(:,3:4) * [1; 1j]), 1:length(pq_rand), 'uni', 0)), 2);
    
    error_total = data_rand_result - repmat(total_load, profile_reps, 1);
    e_mean = mean(error_total);
    e_std = std(error_total);
    
    figure(2);
    plot(t_reps, error_total);
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
    
    if i_max < 0 || (round(abs(e_mean+e_std)*1000) == 0 && round(abs(e_mean-e_std)*1000) == 0)
        break
    end
    
    data_rand{end+1} = data_rand{end} - error_total .* data_rand{end} ./ sum(data_rand{end}, 2);
end

return
%% Now do the voltage assessment

voltages = double(cell2mat(arrayfun(@(x) x.data(:, 3), vi_rand_corrected, 'uni', 0)));
voltages = reshape(voltages, [], profile_reps, dss.get_load_count());

boxplot(reshape(voltages, [], dss.get_load_count()));

%% Get distance to node

[load_distances, load_names] = dss.get_load_distances();
plot(load_distances);
% plot(load_distances, squeeze(voltages(1, 1, :)), 'x');
% hold on
% arrayfun(@(x) text(load_distances(x), voltages(1, 1, x), load_names{x}), 1:length(load_names));
% hold off



%% Stop here
return
