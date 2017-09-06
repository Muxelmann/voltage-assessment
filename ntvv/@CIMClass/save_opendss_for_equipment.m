function [ cn, terminals ] = save_opendss_for_equipment( self, equipment )
%SAVE_OPENDSS_FOR_ELEMENT Saves element to OpenDSS file

% Find the equipment's terminals
terminals = self.get_elements_by_resource(equipment.id, 'cim:Terminal');
% Populate the corresponding new connectivity nodes
cn = repmat({[]}, 1, length(terminals));
for i = 1:length(terminals)
    cn{i} = self.get_element_by_id(terminals{i}.connectivity_node, 'cim:ConnectivityNode');
end

switch equipment.tag
    otherwise
        warning(sprintf('No idea how to save %s\n%s\n', equipment.tag, self.get_string(equipment)));
end

end

