function [ ele ] = get_elements_by_resource( self, res, search_eles )

if exist('search_eles', 'var') == 0
    search_eles = self.ele;
elseif isstr(search_eles)
    search_eles = self.get_elements_by_tag(search_eles);
end

idx = cellfun(@(x) contains_resource(x, res), search_eles);

if sum(idx) == 0
    warning(['no element containing resource ID <' res '>']);
    ele = {};
    return
end

ele = search_eles(idx);
end

function result = contains_resource(ele, res)

%% check each field content

% Get all field names ...
field_names = fieldnames(ele);
% Remove id from field names (avoid loopback)
field_names(cellfun(@(x) strcmp(x, 'id'), field_names)) = [];

% Get all element values
field_values = cellfun(@(x) ele.(x), field_names, 'uni', 0);
% Find those that are cells...
idx_cells = cellfun(@(x) iscell(x), field_values);
% ... append content to end...
field_values = [field_values; field_values{idx_cells}];
% ... and remove the cells
field_values(find(idx_cells)) = [];


result = any(cellfun(@(x) strcmp(x, res), field_values));
end