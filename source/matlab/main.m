close all
clear

%% Run basic simulation
dss_master_path = dir('../LVTestCase/Master.dss');
dss_data_dir = dir('../Daily_1min_100profiles/*.txt');

dss = DSSClass(fullfile(dss_master_path.folder, dss_master_path.name));

% Add ESMU
dss.put_esmu_at_bus('318');
[load_zones] = dss.get_load_meters();
[load_phases] = dss.get_load_phases();

% Ser loads
data = [];
for i = 1:length(dss_data_dir)
    data_new = csvread(fullfile(dss_data_dir(i).folder, dss_data_dir(i).name));
    data = [data, data_new];
end
dss.set_load_shape([data(:, 1:dss.get_load_count()-3) zeros(size(data, 1), 3)]);

% dss.down_stream_customers();

[load_distances, load_names] = dss.get_load_distances();
% plot(load_distances, 'x');
% hold on
% arrayfun(@(x) text(x, load_distances(x), load_names{x}, 'Rotation', -60), 1:length(load_distances));
% hold off

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

% Use this with ESMU
rand_load = {[...
    rand(size(actual_load, 1) * profile_reps, dss.get_load_count() - 3)...
    zeros(size(actual_load, 1) * profile_reps, 3) ...
    ]};
% % Use this without ESMU
% rand_load = {rand(size(actual_load, 1) * profile_reps, dss.get_load_count())};

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
    for p = 1:3
        subplot(1, 3, p);
        plot(t_reps, rand_load_error_total(:, p));
        ax = gca;
        hold on
        line(ax.XLim, ones(2,1) * e_mean(p), 'Color', 'r');
        line(ax.XLim, ones(2,1) * e_mean(p)+e_std(p), 'Color', 'r', 'LineStyle', '--');
        line(ax.XLim, ones(2,1) * e_mean(p)-e_std(p), 'Color', 'r', 'LineStyle', '--');
        hold off
        xlabel('time (h)');
        ylabel('power error (kVA)');
        title(['mean: ' num2str(e_mean(p)) ' | std: ' num2str(e_std(p))]);
        drawnow
    end
    
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

save('tmp', '-regexp', '^(?!(dss|dss)$).')

%% Now do the voltage matching
clearvars -except dss
load('tmp.mat');

% Identify all up stream loads for phase
loads_up_stream = cell2mat(arrayfun(@(x) load_zones == 1 & load_phases == x, 1:3, 'uni', 0));
% Identify all down stream loads for phase
loads_down_stream = cell2mat(arrayfun(@(x) load_zones == 2 & load_phases == x, 1:3, 'uni', 0));
% Make a load location vector
loads_location = cat(3, loads_up_stream, loads_down_stream);

% Define fmincon parameters
A = [];
b = [];
Aeq = [];
beq = [];
lb = ones(1, 3) * -1;
ub = ones(1, 3) * 1;
fmincon_opt = optimoptions(@fmincon);
fmincon_opt.PlotFcns = {@optimplotx, @optimplotfval};
fmincon_opt.OptimalityTolerance = 1e-4;
fmincon_opt.Display = 'none';
fmincon_opt.FiniteDifferenceStepSize = 1e-3;

rand_load_next = nan(size(rand_load{end}));
for t = 1:size(rand_load_next, 1)
    fprintf('starting: %5d', t);
    rand_load_t = rand_load{end}(t, :);
    v_actual = actual_voltages(t, end-2:end);
    [load_scale, ~, exitflag] = fmincon(@(x) cost_voltage_offset(x, rand_load_t, loads_location, dss, v_actual, dss.get_load_count() - [2 1 0]), ...
        zeros(1, 3), A, b, Aeq, beq, lb, ub, [], fmincon_opt);
    
    assert(exitflag > 0);
    
    [~, load_data_scaled] = cost_voltage_offset(load_scale, rand_load_t, loads_location, dss, v_actual, dss.get_load_count() - [2 1 0]);
    rand_load_next(t, :) = load_data_scaled;
    fprintf(' -> DONE\n');
end
return
%% Test if this worked

rand_load_next_test = rand_load_next(isnan(rand_load_next(:, 1)) == 0, :);
rand_load_last_test = rand_load{end}(1:size(rand_load_next_test, 1), :);

dss.set_load_shape(rand_load_last_test);
dss.reset();
dss.solve();

[~, v_sim_1] = dss.get_monitor_data();
v_sim_1 = double(reshape(cell2mat(arrayfun(@(x) v_sim_1(x).data(:, 3), 1:length(v_sim_1), 'uni', 0)), [], dss.get_load_count()));

dss.set_load_shape(rand_load_next_test);
dss.reset();
dss.solve();

[~, v_sim_2] = dss.get_monitor_data();
v_sim_2 = double(reshape(cell2mat(arrayfun(@(x) v_sim_2(x).data(:, 3), 1:length(v_sim_2), 'uni', 0)), [], dss.get_load_count()));

subplot(2, 1, 1);
plot(actual_voltages(1:size(v_sim_1, 1), end-2:end), 'b')
hold on
plot(v_sim_1(:, end-2:end), 'r');
plot(v_sim_2(:, end-2:end), 'g');
hold off
subplot(2, 1, 2);
plot(v_sim_1(:, end-2:end) - actual_voltages(1:size(v_sim_1, 1), end-2:end), 'r');
hold on
plot(v_sim_2(:, end-2:end) - actual_voltages(1:size(v_sim_2, 1), end-2:end), 'g');
hold off

%%

imagesc(rand_load_next_test - rand_load{end}(1:size(rand_load_next_test, 1), :))
colorbar()

%% Now do the voltage matching

% This sort of works, but not all three phases converge; only one or two do
z1 = dss.get_impedance_at_bus('318');

load('tmp');

last_p_idx = length(rand_load);
i_max = 100; % Stop after `i_max` iteration

while true
    if i_max <= 0
        break
    else
        i_max = i_max - 1;
    end
    
    % Run simulation to get voltage levels (1st is technically redundant, but
    % do it so that I can easily debug the code
    dss.set_load_shape(rand_load{end});
    dss.solve();
    
    % Extract voltages for each load
    [~, vi_rand] = dss.get_monitor_data();
    rand_voltages = double(reshape(cell2mat(arrayfun(@(x) vi_rand(x).data(:, 3), 1:length(vi_rand), 'uni', 0)), [], dss.get_load_count()));
    
    rand_voltages_error = rand_voltages(:, end-2:end) - repmat(actual_voltages(:, end-2:end), profile_reps, 1);
    e_mean = mean(rand_voltages_error);
    e_std = std(rand_voltages_error);
    
    fprintf('voltage matching: %2d : %.5f %.5f %.5f ; %.5f %.5f %.5f\n', i_max, e_mean, e_std);
    figure(3);
    for p = 1:3
        subplot(1, 3, p);
        plot(t_reps, rand_voltages_error(:, p));
        ax = gca;
        hold on
        line(ax.XLim, ones(2,1) * e_mean(p), 'Color', 'r');
        line(ax.XLim, ones(2,1) * e_mean(p) + e_std(:, p), 'Color', 'r', 'LineStyle', '--');
        line(ax.XLim, ones(2,1) * e_mean(p) - e_std(:, p), 'Color', 'r', 'LineStyle', '--');
        hold off
        xlabel('time (h)');
        ylabel('voltage error (V)');
        title(['mean: ' num2str(e_mean(p)) ' | std: ' num2str(e_std(p))]);
    end
    drawnow
    % abs(rand_voltages_error(:)) < v_tol
    if all(round(abs(e_mean+e_std)*100) == 0) && all(round(abs(e_mean-e_std)*100) == 0)
        break
    end
    
    % Prepare to calculate the updated load to correct voltages
    rand_load_final = double(rand_load{end});
    rand_load_next = nan(size(rand_load{end}));
    for p = 1:3
        % Find voltage error for phase
        rand_voltages_error = rand_voltages(:, end-3+p) - repmat(actual_voltages(:, end-3+p), profile_reps, 1);
        
        % Identify all up stream loads for phase
        loads_up_stream = load_zones == 1 & load_phases == p;
        % Identify all down stream loads for phase
        loads_down_stream = load_zones == 2 & load_phases == p;
        
        % Compute total up stream load
        load_up_stream_total = sum(rand_load_final(:, loads_up_stream), 2);
        % Compute how much each load contributes towards total up stream load
        load_up_stream_fraction = rand_load_final(:, loads_up_stream) ./ load_up_stream_total;
        % Compute total down stream load
        load_down_stream_total = sum(rand_load_final(:, loads_down_stream), 2);
        % Compute how much each load contributes towards total down stream load
        load_down_stream_fraction = rand_load_final(:, loads_down_stream) ./ load_down_stream_total;
        
        % For all instances where voltage was too low ...
        v_idx = rand_voltages_error < 0;
        % ... decrease down stream by 10% ...
        %  rand_load_next(v_idx, loads_down_stream) = 0.9 * load_down_stream_total(v_idx) .* load_down_stream_fraction(v_idx, :);
        p_adj = 1 - 0.5 .* abs(rand_voltages_error(v_idx)).^(0.1);
        rand_load_next(v_idx, loads_down_stream) = p_adj .* load_down_stream_total(v_idx) .* load_down_stream_fraction(v_idx, :);
        
        % For all instances where voltage was too high ...
        v_idx = rand_voltages_error >= 0;
        % ... decrease down stream by 5%
        % rand_load_next(v_idx, loads_down_stream) = 1.05 * load_down_stream_total(v_idx) .* load_down_stream_fraction(v_idx, :);
        p_adj = 1 + 0.5 .* abs(rand_voltages_error(v_idx)).^(0.1);
        rand_load_next(v_idx, loads_down_stream) = p_adj .* load_down_stream_total(v_idx) .* load_down_stream_fraction(v_idx, :);
        
        
        % rand_load_next(:, loads_down_stream) = (1 + sign(rand_voltages_error) .* sqrt(abs(rand_voltages_error)) / 5) .* load_down_stream_total .* load_down_stream_fraction;

        % ... find out how much that is in total ...
        rand_load_next_diff = load_down_stream_total - sum(rand_load_next(:, loads_down_stream), 2);
        % ... and increas upsteam equally
        rand_load_next(:, loads_up_stream) = (load_up_stream_total + rand_load_next_diff) .* load_up_stream_fraction;
    end
    
%     % Display difference
%     figure(1);
%     for p = 1:3
%         subplot(1, 3, p);
%         plot(sum(rand_load_next(:, load_phases==p & load_zones==1) - rand_load{last_p_idx}(:, load_phases==p & load_zones==1), 2));
%         colorbar();
%     end
%     drawnow
    
    % Append next load and simulate
    rand_load{end+1} = rand_load_next;
end

% Show difference between last error and now...
% figure(4)
% old_error = rand_voltages(:, end-2:end) - repmat(actual_voltages(:, end-2:end), profile_reps, 1);
% rand_voltages_next = double(reshape(cell2mat(arrayfun(@(x) vi_rand(x).data(:, 3), 1:length(vi_rand), 'uni', 0)), [], dss.get_load_count()));
% next_error = rand_voltages_next(:, end-2:end) - repmat(actual_voltages(:, end-2:end), profile_reps, 1);
% 
% for p = 1:3
%     subplot(1, 3, p);
%     plot([old_error(:, p), next_error(:, p)]);
% end
% 
% mean(abs(old_error) - abs(next_error))

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
