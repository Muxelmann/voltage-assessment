function [ load_shape_new ] = adjust_load_shapes( phase_percent, load_shape, loads_location )
%ADJUST_LOAD_SHAPES Summary of this function goes here
%   Detailed explanation goes here

load_shape_new = nan(size(load_shape));

for p = 1:3
    load_up_down = {...
        load_shape(:, loads_location(:, p, 1)), ...
        load_shape(:, loads_location(:, p, 2))};
    
    rand_frac = {...
        load_up_down{1} ./ sum(load_up_down{1}, 2), ...
        load_up_down{2} ./ sum(load_up_down{2}, 2)};
    
    load_shape_new(:, loads_location(:, p, 1)) = rand_frac{1} .* sum(sum(load_up_down{1}, 2) + sum(load_up_down{2}, 2)) .* phase_percent(p);
    load_shape_new(:, loads_location(:, p, 2)) = rand_frac{2} .* sum(sum(load_up_down{1}, 2) + sum(load_up_down{2}, 2)) .* (1-phase_percent(p));
end

end

