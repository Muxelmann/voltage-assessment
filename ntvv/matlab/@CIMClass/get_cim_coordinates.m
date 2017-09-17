function [ ele ] = get_cim_coordinates( node )
% GET_CIM_COORDINATES saves the coordinates for a node
% and aims to append it to the corresponding element
    
switch char(node.getNodeName)
    case 'nmm:DeviceMember'
        ele = get_id(node);
        ele.coord_type = get_data(node, 'nmm:FieldName');
        switch ele.coord_type
            case 'location'
                ele.coords = get_data(node, 'gml:pos');
            case 'route'
                ele.coords = get_data(node, 'gml:posList');
            case 'path'
                ele.coords = get_data(node, 'gml:posList');
            otherwise
                warning([char(node) ' has unimplemented coordinate type: ' ele.coord_type]);
                ele.coords = {};
        end
        
        if isempty(ele.coords)
            ele.coords = [];
        else
            ele.coords = cellfun(@(x) str2double(x), strsplit(ele.coords, ' '));
            ele.coords = reshape(ele.coords, 2, [])';
        end
    case 'nmm:NMMBoundedBy'
        ele = {};
    otherwise
        warning([char(node) ' not implemented!']);
        ele = [];
end

end

function ele = get_id(node)
ele = [];
ele.id = get_data(node, 'nmm:ID');
end

function dat = get_data(node, tag)
tmp = node.getElementsByTagName(tag);
if tmp.getLength == 0
    dat = '';
elseif tmp.getLength == 1
    dat = char(tmp.item(0).getChildNodes.item(0).getData);
elseif tmp.getLength > 1
    dat = repmat({[]}, tmp.getLength, 1);
    for i = 1:tmp.getLength
        dat{i} = char(tmp.item(i-1).getChildNodes.item(0).getData);
    end
else
    assert(false, ['data for ' tag ' in ' node ' caused an error']);
end
end
