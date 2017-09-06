function [ ele ] = get_element_by_id( self, id, search_eles )

if exist('search_eles', 'var') == 0
    search_eles = self.ele;
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

end

