function [ ele ] = remove_elements_from_set( self, remove_eles, search_eles )

if exist('search_eles', 'var') == 0
    search_eles = self.ele;
end

idx = cellfun(@(x) any(cellfun(@(y) strcmp(x.id, y.id), remove_eles)) == 0, search_eles);
ele = search_eles(idx);

end

