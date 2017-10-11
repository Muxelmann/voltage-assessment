function [ rand_load ] = match_random_load( profile_reps, actual_load, dss, has_esmu )
%MATCH_RANDOM_LOAD Matches a random load profile to an actual load
%   Detailed explanation goes here

if exist('has_esmu', 'var') == 0
    has_esmu = true;
end

% Get load phasing
[load_phases] = dss.get_load_phases();

% Make a random load profile
rand_load = {rand(size(actual_load, 1) * profile_reps, dss.get_load_count())};
% Set ESMU to be off
if has_esmu
    rand_load{end}(:, end-2:end) = zeros(size(actual_load, 1) * profile_reps, 3);
end

% Scale all loads to approximate the actual load
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
    
    % get the new network load
    [pq_rand, ~] = dss.get_monitor_data('txfrmr_mon_');
    rand_load_result = abs(double(cell2mat(arrayfun(@(x) pq_rand.data(:, (x*2)-1+2) + 1j*pq_rand.data(:, (x*2)+2), 1:3, 'uni', 0))));
    
    % calculate the error from running this random profile
    rand_load_error_total = rand_load_result - repmat(actual_load, profile_reps, 1);
    e_mean = mean(rand_load_error_total);
    e_std = std(rand_load_error_total);
    e_min = min(rand_load_error_total);
    e_max = max(rand_load_error_total);
    
    figure(2);
    for p = 1:3
        subplot(1, 3, p);
        plot(t_reps, rand_load_error_total(:, p), 'Color', 'b');
        ax = gca;
        hold on
        line(ax.XLim, ones(2,1) * e_max(p), 'Color', 'b', 'LineStyle', '--');
        line(ax.XLim, ones(2,1) * e_min(p), 'Color', 'b', 'LineStyle', '--');
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
    
    if i_max < 0 || (all(round(abs(e_max)*1000) == 0) && all(round(abs(e_min)*1000) == 0))
        break
    end
    
    rand_load_next = nan(size(rand_load{end}));
    for p = 1:3
        rand_load_next(:, load_phases == p) = rand_load{end}(:, load_phases == p) - rand_load_error_total(:, p) .* rand_load{end}(:, load_phases == p) ./ sum(rand_load{end}(:, load_phases == p), 2);
    end
    rand_load{end+1} = rand_load_next;
end

% save('tmp', '-regexp', '^(?!(dss|dss)$).')

end

