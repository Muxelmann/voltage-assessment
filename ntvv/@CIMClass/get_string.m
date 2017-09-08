function [ tags ] = get_string( self, search_eles )

if exist('search_eles', 'var') == 0
    search_eles = self.ele;
end

if iscell(search_eles) == 0
    tags = get_element_string(search_eles);
else
    tags = cellfun(@(x) get_element_string(x), search_eles, 'uni', 0);
    tags = reshape(tags, [], 1);
end
end

function ele_string = get_element_string(ele)
ele_string = [ele.id ' ['];

field_names = fieldnames(ele);
field_names(cellfun(@(x) strcmp(x, 'id'), field_names)) = [];
for i = 1:length(field_names)
    field_value = ele.(field_names{i});
    if isnumeric(field_value)
        field_value = ['[' strjoin(reshape(arrayfun(@(x) sprintf('%2.10f', x), field_value', 'uni', 0), 1, []), ', ') ']'];
    end
    if iscell(field_value)
        field_value = ['[' strjoin(reshape(field_value, 1, []), ', ') ']'];
    end
    if i > 1
        ele_string = [ele_string ', ' field_names{i} ': ' field_value];
    else
        ele_string = [ele_string field_names{i} ': ' field_value];
    end
end

ele_string = [ele_string ']'];
end

