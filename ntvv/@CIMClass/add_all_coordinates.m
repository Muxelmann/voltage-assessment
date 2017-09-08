function [ self ] = add_all_coordinates( self, xml_file )

xml_data = xmlread(xml_file);
nmm_data = xml_data.getElementsByTagName('nmm:NMMFeatureCollection');

assert(nmm_data.getLength <= 1, 'CIMClass:find_all_elements:nmm-error', ...
    ['Found NMM ' num2str(nmm_data.getLength) ' times']);

self.ele_buffers = [];

if nmm_data.getLength == 0
    return
end

nmm_data = nmm_data.item(0);

nodes = nmm_data.getChildNodes;
for i = 1:nodes.getLength
    node = nodes.item(i-1);
    
    if strcmp(char(node.getNodeName), '#text')
        continue
    end
    
    % New connectivity node
    ele_coord = self.get_cim_coordinates(node);
    
    if isfield(ele_coord, 'id') == 1
        [ele, idx] = self.get_element_by_id(ele_coord.id);
        ele.coords = ele_coord.coords;
        self.ele{idx} = ele;
    end
    
end

end

