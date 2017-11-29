function [ rand_profile ] = make_random_profile(actual_load, dss, ignore_idx )
%MAKE_RANDOM_PROFILES Summary of this function goes here
%   Detailed explanation goes here

% Make a random load profile
rand_profile = rand(size(actual_load, 1), dss.get_load_count());
% Set certain profiles to zero power (i.e. those to ignore)
if isempty(ignore_idx) == 0
    rand_profile(:, ignore_idx) = zeros(size(actual_load, 1), length(ignore_idx));
end

% Get load phasing
[load_phases] = dss.get_load_phases();

% Scale all loads to approximate the actual load
rand_load_scale = cell2mat(arrayfun(@(x) actual_load(:, x) ./ sum(rand_profile(:, load_phases == x), 2), 1:3, 'uni', 0));
for p = 1:3
    rand_profile(:, load_phases == p) = rand_profile(:, load_phases == p) .* rand_load_scale(:, p);
end

end

