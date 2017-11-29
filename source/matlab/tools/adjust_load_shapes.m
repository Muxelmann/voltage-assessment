function [ loads_new ] = adjust_load_shapes( loads_scaling, loads_original, dss )
%ADJUST_LOAD_SHAPES Assigns load proportion to upper and lower energy zone

if size(loads_scaling, 1) > 1 && size(loads_original, 1) > 1
    loads_new = arrayfun(@(x) adjust_load_shapes(loads_scaling(x, :), loads_original(x, :), dss), 1:size(loads_original, 1), 'uni', 0);
    loads_new = cell2mat(loads_new.');
    return
end

assert(size(loads_scaling, 1) == 1 && size(loads_original, 1) == 1);

% Get the load locations
load_location = dss.get_load_location();
load_count = size(load_location, 1);
phase_count = size(load_location, 2);
zone_count = size(load_location, 3);

% Map load scaling to each load
loads_scaling = reshape(loads_scaling, 1, phase_count, zone_count);
loads_scaling = repmat(loads_scaling, load_count, 1, 1);

% Find the fraction of load that is consumed by each load within its energy
% zone and phase
load_frac = repmat(loads_original(:), 1, phase_count, zone_count);
load_frac(load_location == 0) = 0;
load_total = repmat(sum(load_frac, 1), load_count, 1, 1);
load_frac = load_frac ./ load_total;

% Multiply with load proportion to get new but correctly scaled
loads_new = load_frac .* load_total .* loads_scaling;
loads_new = sum(sum(loads_new, 3), 2).';

end

