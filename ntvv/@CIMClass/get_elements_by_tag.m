function [ ele ] = get_elements_by_tag( self, tag, search_eles )

if exist('search_eles', 'var') == 0
    search_eles = self.ele;
end

idx = cellfun(@(x) strcmp(x.tag, tag), search_eles);

if sum(idx) == 0
    warning(['no element found for tag <' tag '>']);
    ele = {};
    return
end

ele = search_eles(idx);

end

