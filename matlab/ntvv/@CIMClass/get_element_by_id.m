function [ ele, idx ] = get_element_by_id( self, id, search_eles )

if exist('search_eles', 'var') == 0
    search_eles = self.ele;
elseif ischar(search_eles)
    search_eles_field = strrep(search_eles, ':', '_');
    if isfield(self.ele_buffers, search_eles_field) == 0
        self.ele_buffers.(search_eles_field) = self.get_elements_by_tag(search_eles);
    end
    search_eles = self.ele_buffers.(search_eles_field);
end

idx = cellfun(@(x) strcmp(x.id, id), search_eles);

if sum(idx) == 0
    warning(['no element with ID <' res '>']);
    ele = {};
    return
end

if sum(idx) > 1
    warning(['too many elements for ID <' res '>: ' num2str(sum(idx))]);
    ele = {};
    return
end

ele = search_eles{idx};
idx = find(idx);
end

