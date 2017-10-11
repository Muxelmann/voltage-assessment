function [ load_new ] = adjust_load_shapes( load_proportion, load, dss )
%ADJUST_LOAD_SHAPES Assigns load proportion to upper and lower energy zone

if size(load_proportion, 1) > 1 && size(load, 1) > 1
    load_new = arrayfun(@(x) adjust_load_shapes(load_proportion(x, :), load(x, :), dss), 1:size(load, 1), 'uni', 0);
    load_new = cell2mat(load_new.');
    return
end

assert(size(load_proportion, 1) == 1 && size(load, 1) == 1);

% Get the load locations
load_location = dss.get_load_location();

% Map load proportion
load_proportion = reshape(load_proportion, 1, size(load_location, 2), size(load_location, 3));
load_proportion = repmat(load_proportion, size(load_location, 1), 1, 1);

% Find the fraction of load that is consumed by each load within its energy
% zone and phase
load_frac = repmat(load(:), 1, size(load_location, 2), size(load_location, 3));
load_frac(load_location == 0) = 0;
load_total = repmat(sum(load_frac, 1), size(load_location, 1), 1, 1);
load_frac = load_frac ./ load_total;

% Find the total load per phase
load_total = repmat(sum(load_total, 3), 1, 1, size(load_location, 3));

% Multiply with load proportion to get new but correctly scaled
load_new = load_frac .* load_total .* load_proportion;
load_new = sum(sum(load_new, 3), 2).';

end

