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

dss.put_esmu_at_bus('318');
[load_zones] = dss.get_load_meters();


%% Display feeder
% dss.down_stream_customers();

%%
[load_distances, load_names] = dss.get_load_distances();
plot(load_distances, 'x');
hold on
arrayfun(@(x) text(x, load_distances(x), load_names{x}), 1:length(load_distances));
hold off
return

%% Loads order

load_names = {};
idx = dss.dss_circuit.Loads.First;
while idx > 0
    load_names{end+1} = dss.dss_circuit.Loads.Name;
    idx = dss.dss_circuit.Loads.Next;
end

%%
dss.down_stream_customers('666');

%%
dss.solve();

[pq, vi] = dss.get_monitor_data();

total_load = double(cell2mat(arrayfun(@(x) abs(x.data(:,3:4) * [1; 1j]), pq, 'uni', 0)));
total_load = sum(total_load, 2);

voltages = double(cell2mat(arrayfun(@(x) x.data(:, 3), vi, 'uni', 0)));


figure(1);
yyaxis left
plot((1:1440)/60, total_load)

yyaxis right
plot((1:1440)/60, mean(voltages, 2));
hold on
plot((1:1440)/60, max(voltages, [], 2));
plot((1:1440)/60, min(voltages, [], 2));
hold off


%% Generate random loads that have the same power profile n times

profile_reps = 10;

data_rand = rand(length(total_load), profile_reps, dss.get_load_count());
data_scale = total_load ./ sum(data_rand, 3);
data_rand = data_rand .* data_scale;

% run this random profile
dss.set_load_shape(reshape(data_rand, [], dss.get_load_count()));
dss.solve();

[pq_rand, vi_rand] = dss.get_monitor_data();

% Calculate the error from running this random profile
total_load_rand = cell2mat(arrayfun(@(x) abs(pq_rand(x).data(:,3:4) * [1; 1j]), 1:length(pq_rand), 'uni', 0));
total_load_rand = sum(total_load_rand, 2);
plot(total_load_rand)

total_load_error = reshape(total_load_rand, 1440, []) - total_load;
plot(total_load_error(:));

%% Correct each load to reduce the error

data_rand_corrected = data_rand;

% Stop after `i_max` iterations or when reaching the closest 1 Watt
i_max = 10;
while true
    data_rand_corrected = data_rand_corrected - total_load_error .* data_rand ./ sum(data_rand, 3);
    dss.set_load_shape(reshape(data_rand_corrected, [], dss.get_load_count()));
    dss.solve();
    
    [pq_rand_corrected, vi_rand_corrected] = dss.get_monitor_data();
    
    total_load_rand_corrected = cell2mat(arrayfun(@(x) abs(pq_rand_corrected(x).data(:,3:4) * [1; 1j]), 1:length(pq_rand_corrected), 'uni', 0));
    total_load_rand_corrected = sum(total_load_rand_corrected, 2);
    plot(total_load_rand_corrected)
    
    total_load_error = reshape(total_load_rand_corrected, 1440, []) - total_load;
    
    e_mean = mean(total_load_error(:));
    e_std = std(total_load_error(:));
    
    figure(1);
    plot(total_load_error(:));
    ax = gca;
    hold on
    line(ax.XLim, ones(2,1) * e_mean, 'Color', 'r');
    line(ax.XLim, ones(2,1) * e_mean+e_std, 'Color', 'r', 'LineStyle', '--');
    line(ax.XLim, ones(2,1) * e_mean-e_std, 'Color', 'r', 'LineStyle', '--');
    hold off
    f = gcf;
    f.Name = ['mean: ' num2str(e_mean) ' | std: ' num2str(e_std)];
    drawnow
    
    i_max = i_max - 1;
    
    if i_max < 0 || (round(abs(e_mean+e_std)*1000) == 0 && round(abs(e_mean-e_std)*1000) == 0)
        break
    end
end

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
