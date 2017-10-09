close all
clear

% Run basic simulation
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

data = data(1:10,1:dss.get_load_count()-3);
dss.set_load_shape([data zeros(size(data, 1), 3)]);

[load_distances, load_names] = dss.get_load_distances();

dss.reset(); % Resets all monitors and energy-meters
dss.solve(); % Solves the time-series

[pq, ~] = dss.get_monitor_data('txfrmr_mon_'); % Get monitor's data

actual_load = abs(double(cell2mat(arrayfun(@(x) pq.data(:, (x*2)-1+2) + 1j*pq.data(:, (x*2)+2), 1:3, 'uni', 0))));
% actual_load = cell2mat(arrayfun(@(x) sum(actual_load(:, load_phases == x), 2), 1:3, 'uni', 0));

[~, vi] = dss.get_monitor_data('load_mon_'); % Get monitor's data
actual_voltages = double(reshape(cell2mat(arrayfun(@(x) vi(x).data(:, 3), 1:length(vi), 'uni', 0)), [], dss.get_load_count()));

profile_reps = 1; % Define the number of profile repetitions

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

i_max = 100; % Stop after `i_max` iterations
t_reps = (1:size(rand_load{end}, 1)) / 60;
while true
    % run this random profile
    dss.set_load_shape(rand_load{end});
    dss.solve();
    
    [pq_rand, ~] = dss.get_monitor_data('txfrmr_mon_');
    
    % Calculate the error from running this random profile
    rand_load_result = abs(double(cell2mat(arrayfun(@(x) pq_rand.data(:, (x*2)-1+2) + 1j*pq_rand.data(:, (x*2)+2), 1:3, 'uni', 0))));
    
    rand_load_error_total = rand_load_result - repmat(actual_load, profile_reps, 1);
    e_mean = mean(rand_load_error_total);
    e_std = std(rand_load_error_total);
    
    disp(['mean: ' num2str(e_mean(p)) ' | std: ' num2str(e_std(p))]);
    
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

% Stop here
% return

%% Assess the voltages

dss.set_load_shape(rand_load{end});
dss.solve();
[~, vi_rand] = dss.get_monitor_data('load_mon_');
rand_voltages = cell2mat(arrayfun(@(x) x.data(:, 3), vi_rand, 'uni', 0));

plot(rand_voltages(:, end-2), 'r-');
hold on
plot(rand_voltages(:, end-1), 'r--');
plot(rand_voltages(:, end), 'r:');
plot(actual_voltages(:, end-2), 'b-');
plot(actual_voltages(:, end-1), 'b--');
plot(actual_voltages(:, end), 'b:');
hold off

rand_voltages_error = rand_voltages - repmat(actual_voltages, profile_reps, 1);
rand_voltages_error = rand_voltages_error(:, end-2:end);

%%

% Identify all up stream loads for phase
loads_up_stream = cell2mat(arrayfun(@(x) load_zones == 1 & load_phases == x, 1:3, 'uni', 0));
% Identify all down stream loads for phase
loads_down_stream = cell2mat(arrayfun(@(x) load_zones == 2 & load_phases == x, 1:3, 'uni', 0));
% Make a load location vector
loads_location = cat(3, loads_up_stream, loads_down_stream);

%%

% Define fmincon parameters
A = [];
b = [];
Aeq = [];
beq = [];
lb = zeros(1, 3);
ub = ones(1, 3) * 1;
fmincon_opt = optimoptions(@fmincon);
fmincon_opt.PlotFcns = {@optimplotx, @optimplotfval};
fmincon_opt.OptimalityTolerance = 1e-4;
fmincon_opt.Display = 'none';
fmincon_opt.FiniteDifferenceStepSize = 1e-3;

rand_load_next = rand_load{end};
for t = 1:size(rand_load_next, 1)
    fprintf('starting: %5d', t);
    rand_load_t = rand_load{end}(t, :);
    t_actual = mod(t-1, size(actual_voltages, 1)) + 1;
    v_actual = actual_voltages(t_actual, :);
    [rand_load_adj, ~, exitflag] = fmincon(@(x) cost_voltage_offset(x, rand_load_t, loads_location, dss, v_actual, dss.get_load_count() - [2 1 0]), ...
        ones(1, 3)*0.5, A, b, Aeq, beq, lb, ub, [], fmincon_opt);
    
    assert(exitflag > 0);
    
    rand_load_next(t, :) = adjust_load_shapes(rand_load_adj, rand_load_t, loads_location);
    fprintf(' -> DONE\n');
end
%%

for t = 1:size(rand_load_test, 1)
    rand_load_test(t, :) = adjust_load_shapes([t/100 t/100 t/100], rand_load_test(t, :), loads_location);
end

% p = 1;
% rand_load_up = rand_load_test(:, loads_location(:, p, 1));
% rand_load_down = rand_load_test(:, loads_location(:, p, 2));
% rand_load_up_down = sum(rand_load_up, 2) + sum(rand_load_down, 2);
% rand_load_up_frac = rand_load_up ./ sum(rand_load_up, 2);
% rand_load_down_frac = rand_load_down ./ sum(rand_load_down, 2);
% 
% % rand_load_total = sum(rand_load_test, 2);
% 
% rand_load_test(:, loads_location(:, p, 1)) = rand_load_up_frac .* rand_load_up_down .* linspace(0, 1, 100).';
% rand_load_test(:, loads_location(:, p, 2)) = rand_load_down_frac .* rand_load_up_down .* linspace(1, 0, 100).';

dss.set_load_shape(rand_load_test);
dss.solve()

[~, vi_rand] = dss.get_monitor_data('load_mon_');
rand_voltages = cell2mat(arrayfun(@(x) x.data(:, 3), vi_rand, 'uni', 0));

figure(1)
% imagesc(rand_load_test)
plot(rand_voltages(:, end-2:end) - actual_voltages(end, end-2:end));
%% Now do the voltage matching

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
rand_load_cost = nan(size(rand_load_next, 1), 1);
v_sim_2_cell = {};
for t = 1:size(rand_load_next, 1)
    fprintf('starting: %5d', t);
    rand_load_t = rand_load{end}(t, :);
    t_actual = mod(t-1, size(actual_voltages, 1)) + 1;
    v_actual = actual_voltages(t_actual, :);
    [load_scale, ~, exitflag] = fmincon(@(x) cost_voltage_offset(x, rand_load_t, loads_location, dss, v_actual, dss.get_load_count() - [2 1 0]), ...
        zeros(1, 3), A, b, Aeq, beq, lb, ub, [], fmincon_opt);
    
    assert(exitflag > 0);
    
    [rand_load_cost(t), load_data_scaled, v_sim_2_cell{t}] = cost_voltage_offset(load_scale, rand_load_t, loads_location, dss, v_actual, dss.get_load_count() - [2 1 0]);
    rand_load_next(t, :) = load_data_scaled;
    fprintf(' -> DONE\n');
end

%% Test if this worked

rand_load_last_test = rand_load{end};
rand_load_next_test = rand_load_next;

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

v_sim_1_diff = v_sim_1(:, end-2:end) - repmat(actual_voltages(:, end-2:end), profile_reps, 1);
v_sim_2_diff = v_sim_2(:, end-2:end) - repmat(actual_voltages(:, end-2:end), profile_reps, 1);

cost_1 = sum(abs(v_sim_1(:, end-2:end) - actual_voltages(:, end-2:end)), 2);
cost_2 = sum(abs(v_sim_2(:, end-2:end) - actual_voltages(:, end-2:end)), 2);
% cost_2_c = rand_load_cost;

v_actual = repmat(actual_voltages(:, end-2:end), profile_reps, 1);
v_actual_vec = reshape(v_actual, [], 1);
v_sim_1_vec = reshape(v_sim_1(:, end-2:end), [], 1);
v_sim_2_vec = reshape(v_sim_2(:, end-2:end), [], 1);
% v_sim_2_vec_c = cell2mat(v_sim_2_cell.');

figure(2)
plot(v_sim_1(:, end-2), 'r-');
hold on
plot(v_sim_1(:, end-1), 'r--');
plot(v_sim_1(:, end-0), 'r:');
plot(v_sim_2(:, end-2), 'g-');
plot(v_sim_2(:, end-1), 'g--');
plot(v_sim_2(:, end-0), 'g:');
plot(v_actual(:, end-2), 'b-');
plot(v_actual(:, end-1), 'b--');
plot(v_actual(:, end-0), 'b:');
hold off

figure(3)
for p = 1:3
    subplot(4, 1, p);
    plot([v_sim_1(:, end-3+p), v_sim_2(:, end-3+p)] - actual_voltages(:, end-3+p))
    xlabel('time (min)');
    ylabel('diff voltage (V)');
end
subplot(4, 1, 4);
plot([cost_1 cost_2]);
xlabel('time (min)');
ylabel('$\sum_{p=1}^3 |v_{p} - v_{actual, p}|$', 'Interpreter', 'latex');
%%
subplot(1, 1, 1);
boxplot([v_actual_vec(:) - v_sim_1_vec(:), v_actual_vec(:) - v_sim_2_vec(:)])
%%
subplot(2, 1, 1);
plot(repmat(actual_voltages(:, end-2:end), profile_reps, 1), 'b')
hold on
plot(v_sim_1(:, end-2:end), 'r');
plot(v_sim_2(:, end-2:end), 'g');
hold off
subplot(2, 1, 2);
plot(v_sim_1(:, end-2:end) - repmat(actual_voltages(:, end-2:end), profile_reps, 1), 'r');
hold on
plot(v_sim_2(:, end-2:end) - repmat(actual_voltages(:, end-2:end), profile_reps, 1), 'g');
hold off
%%

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


