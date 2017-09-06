function [ self ] = add_all_elements( self, xml_file )

xml_data = xmlread(xml_file);
rdf_data = xml_data.getElementsByTagName('rdf:RDF');

assert(rdf_data.getLength <= 1, 'CIMClass:find_all_elements:rdf-error', ...
    ['Found RDF ' num2str(rdf_data.getLength) ' times']);

if rdf_data.getLength == 0
    return
end

rdf_data = rdf_data.item(0);

nodes = rdf_data.getChildNodes;
for i = 1:nodes.getLength
    node = nodes.item(i-1);
    
    if strcmp(char(node.getNodeName), '#text')
        continue
    end
    
    % New connectivity node
    ele = self.get_cim_element(node);
    
    if any(cellfun(@(x) strcmp(x.id, ele.id), self.ele))
        disp([ele.id ' already exists']);
    else
        % appends to all nodes
        self.ele{end+1} = ele;
    end
end



end

