function [ rand_load, i_remain ] = match_random_load( profile_reps, actual_load, dss, has_esmu, do_plot )
%MATCH_RANDOM_LOAD Matches a random load profile to an actual load
%   Detailed explanation goes here

if exist('has_esmu', 'var') == 0
    has_esmu = true;
end

if exist('do_plot', 'var') == 0
    do_plot = false;
end

% Get load phasing
[load_phases] = dss.get_load_phases();

if iscell(profile_reps) == 1
    % Or assign the profile if it already exists
    rand_load = profile_reps;
    profile_reps = round(size(rand_load{end}, 1) / size(actual_load, 1));
else
    % Make a random load profile
    rand_load = {rand(size(actual_load, 1) * profile_reps, dss.get_load_count())};
    % Set ESMU to be off
    if has_esmu
        rand_load{end}(:, end-2:end) = zeros(size(actual_load, 1) * profile_reps, 3);
    end
end

% Scale all loads to approximate the actual load
rand_load_scale = cell2mat(arrayfun(@(x) repmat(actual_load(:, x), profile_reps, 1) ./ sum(rand_load{end}(:, load_phases == x), 2), 1:3, 'uni', 0));
for p = 1:3
    rand_load{end}(:, load_phases == p) = rand_load{end}(:, load_phases == p) .* rand_load_scale(:, p);
end

i_remain = 100; % Stop after `i_remain` iterations
t_reps = (1:size(rand_load{end}, 1)) / 60;
print_string = '';
tic;
while true
    % simulate and get network load
    [rand_load_result, ~] = solve_dss(dss, rand_load{end});
    
    % calculate the error from running this random profile
    rand_load_error_total = rand_load_result - repmat(actual_load, profile_reps, 1);
    % calculate error statistics
    e_mean = mean(rand_load_error_total);
    e_std = std(rand_load_error_total);
    e_min = min(rand_load_error_total);
    e_max = max(rand_load_error_total);
    
    if do_plot
        h = figure(2);
        for p = 1:3
            subplot(3, 1, p);
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
            h.Name = ['remaining iterations: ' num2str(i_remain) '; ' num2str(toc) 's'];
            drawnow
        end
    else
        fprintf(repmat('\b', 1, length(print_string)));
        print_string = sprintf('Iterations remaining: %i (%.2fs)\n', i_remain, toc);
        fprintf('%s', print_string);
    end
    
    i_remain = i_remain - 1;
    
    if i_remain < 0 || (all(round(abs(e_max)*1000) == 0) && all(round(abs(e_min)*1000) == 0))
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

