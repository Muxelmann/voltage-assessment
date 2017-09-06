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
    case 'cim:PowerTransformer'
        save_power_transformer(self, equipment);
    case 'cim:BusbarSection'
        save_busbar_section(self, equipment);
    case 'cim:Disconnector'
        save_disconnector(self, equipment);
    case 'cim:Fuse'
        save_fuse(self, equipment);
    case 'cim:ACLineSegment'
        save_ac_line_segment(self, equipment);
    case 'cim:EnergyServicePoint'
        save_energy_service_point(self, equipment);
    case 'cim:EnergyConsumer'
        save_energy_consumer(self, equipment);
    otherwise
        warning(['No idea how to save ', equipment.tag]);
end

end

function save_power_transformer(self, equipment)
end

function save_busbar_section(self, equipment)
end

function save_disconnector(self, equipment)
end

function save_fuse(self, equipment)
end

function save_ac_line_segment(self, equipment)
end

function save_energy_service_point(self, equipment)
end

function save_energy_consumer(self, equipment)
end





