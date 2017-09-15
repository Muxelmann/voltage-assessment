function [ ele ] = get_cim_element( node )
% GET_CIM_ELEMENT retireves and populates the CIM element for a given node

switch char(node.getNodeName)
    case 'cim:Asset'
        ele = get_asset(node);
    case 'cim:ACLineSegment'
        ele = get_ac_line_segment(node);
    case 'cim:ACLineSegmentPhase'
        ele = get_ac_line_segment_phase(node);
    case 'cim:BaseVoltage'
        ele = get_base_voltage(node);
    case 'cim:Bay'
        ele = get_bay(node);
    case 'cim:BusbarSection'
        ele = get_busbar_section(node);
    case 'cim:BusbarSectionInfo'
        ele = get_busbar_section_info(node);
    case 'cim:CableInfo'
        ele = get_cable_info(node);
    case 'cim:CompositeSwitch'
        ele = get_composite_switch(node);
    case 'cim:ConnectivityNode'
        ele = get_connectivity_node(node);
    case 'cim:Disconnector'
        ele = get_disconnector(node);
    case 'cim:EnergyConsumer'
        ele = get_energy_consumer(node);
    case 'cim:EnergyServicePoint'
        ele = get_energy_service_point(node);
    case 'cim:EnergySource'
        ele = get_energy_source(node);
    case 'cim:Fuse'
        ele = get_fuse(node);
    case 'cim:Line'
        ele = get_line(node);
    case 'cim:LoadBreakSwitch'
        ele = get_load_break_switch(node);
    case 'cim:Pole'
        ele = get_pole(node);
    case 'cim:PowerTransformer'
        ele = get_power_transformer(node);
    case 'cim:PowerTransformerInfo'
        ele = get_power_transformer_info(node);
    case 'cim:PSRType'
        ele = get_psr_type(node);
    case 'cim:RatioTapChanger'
        ele = get_ratio_tap_changer(node);
    case 'cim:Substation'
        ele = get_substation(node);
    case 'cim:SwitchInfo'
        ele = get_switch_info(node);
    case 'cim:SwitchPhase'
        ele = get_switch_phase(node);
    case 'cim:Terminal'
        ele = get_terminal(node);
    case 'cim:TransformerEndInfo'
        ele = get_transformer_end_info(node);
    case 'cim:TransformerTank'
        ele = get_transformer_tank(node);
    case 'cim:TransformerTankEnd'
        ele = get_transformer_tank_end(node);
    case 'cim:TransformerTankInfo'
        ele = get_transformer_tank_info(node);
    case 'cim:OverheadWireInfo'
        ele = get_overhead_wire_info(node);
    case 'cim:UsagePoint'
        ele = get_usage_point(node);
    case 'cim:VoltageLevel'
        ele = get_voltage_level(node);
    otherwise
        warning([char(node) ' not implemented!']);
        ele = get_id(node);
end

end

function ele = get_id(node)
ele = [];
assert(node.hasAttribute('rdf:ID'), ...
    'CIMClass:get_cim_element:no-id', ...
    ['The elemenet ' char(node) ' has no ID']);
ele.id = char(node.getAttribute('rdf:ID'));
ele.tag = char(node.getTagName);
end

function res = get_resource(node, tag)
tmp = node.getElementsByTagName(tag);
if tmp.getLength == 0
    res = '';
elseif tmp.getLength == 1
    res = char(tmp.item(0).getAttribute('rdf:resource'));
    res = strsplit(res, '#');
    res = res{end};
elseif tmp.getLength > 1
    res = repmat({''}, tmp.getLength, 1);
    for i = 1:tmp.getLength
        res{i} = char(tmp.item(i-1).getAttribute('rdf:resource'));
        res{i} = strsplit(res{i}, '#');
        res{i} = res{i}{end};
    end
else
    assert(false, ['resource for ' tag ' in ' node ' caused an error']);
end
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

function ele = get_asset(node)
ele = get_id(node);
ele.type = get_data(node, 'cim:Asset.type');
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.power_system_resource = get_resource(node, 'cim:Asset.PowerSystemResources');
ele.asset_info = get_resource(node, 'cim:Asset.AssetInfo');
end

function ele = get_ac_line_segment(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.length = get_data(node, 'cim:Conductor.length');
ele.psr_type = get_resource(node, 'cim:PowerSystemResource.PSRType');
ele.equipment_container = get_resource(node, 'cim:Equipment.EquipmentContainer');
end

function ele = get_ac_line_segment_phase(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.phase = get_resource(node, 'cim:ACLineSegmentPhase.phase');
ele.ac_line_segment = get_resource(node, 'cim:ACLineSegmentPhase.ACLineSegment');
end

function ele = get_base_voltage(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.base_voltage = get_data(node, 'cim:BaseVoltage.nominalVoltage');
end

function ele = get_bay(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.substation = get_resource(node, 'cim:Bay.Substation');
ele.voltage_level = get_resource(node, 'cim:Bay.VoltageLevel');
end

function ele = get_busbar_section(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.psr_type = get_resource(node, 'cim:PowerSystemResource.PSRType');
ele.voltage_base = get_resource(node, 'cim:ConductingEquipment.BaseVoltage');
ele.equipment_container = get_resource(node, 'cim:Equipment.EquipmentContainer');
end

function ele = get_busbar_section_info(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
end

function ele = get_cable_info(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
end

function ele = get_composite_switch(node)
ele = get_id(node);
ele.composite_switch_type = get_data(node, 'cim:CompositeSwitch.compositeSwitchType');
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.psr_type = get_resource(node, 'cim:PowerSystemResource.PSRType');
ele.equipment_container = get_resource(node, 'cim:Equipment.EquipmentContainer');
end

function ele = get_connectivity_node(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.container = get_resource(node, 'cim:ConnectivityNode.ConnectivityNodeContainer');
end

function ele = get_disconnector(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.normal_open = get_data(node, 'cim:Switch.normalOpen');
ele.psr_type = get_resource(node, 'cim:PowerSystemResource.PSRType');
ele.base_voltage = get_resource(node, 'cim:ConductingEquipment.BaseVoltage');
ele.equipment_container = get_resource(node, 'cim:Equipment.EquipmentContainer');
end

function ele = get_energy_consumer(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.energy_service_point = get_resource(node, 'cim:EnergyConsumer.EnergyServicePoint');
ele.equipment_container = get_resource(node, 'cim:Equipment.EquipmentContainer');
end

function ele = get_energy_service_point(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.type = get_data(node, 'cim:EnergyServicePoint.type');
ele.critical_customer = get_data(node, 'cim:EnergyServicePoint.criticalCustomer');
ele.customer_count = get_data(node, 'cim:EnergyServicePoint.customerCount');
ele.equipment_container = get_resource(node, 'cim:Equipment.EquipmentContainer');
end

function ele = get_energy_source(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.type = get_data(node, 'cim:EnergyServicePoint.type');
ele.critical_customer = get_data(node, 'cim:EnergyServicePoint.criticalCustomer');
ele.customer_count = get_data(node, 'cim:EnergyServicePoint.customerCount');
ele.equipment_container = get_resource(node, 'cim:Equipment.EquipmentContainer');
end

function ele = get_fuse(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.active_power = get_data(node, 'cim:EnergySource.activePower');
ele.psr_type = get_resource(node, 'cim:PowerSystemResource.PSRType');
ele.energy_service_point = get_resource(node, 'cim:EnergySource.EnergyServicePoint');
ele.equipment_container = get_resource(node, 'cim:Equipment.EquipmentContainer');
end

function ele = get_line(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
end

function ele = get_load_break_switch(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.noramal_open = get_data(node, 'cim:Switch.normalOpen');
ele.composite_switch = get_resource(node, 'cim:Switch.CompositeSwitch');
ele.psr_type = get_resource(node, 'cim:PowerSystemResource.PSRType');
ele.base_voltage = get_resource(node, 'cim:ConductingEquipment.BaseVoltage');
ele.equipment_container = get_resource(node, 'cim:Equipment.EquipmentContainer');
end

function ele = get_pole(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
end

function ele = get_overhead_wire_info(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
end

function ele = get_power_transformer(node)
ele = get_id(node);
ele.alias_name = get_data(node, 'cim:IdentifiedObject.aliasName');
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.psr_type = get_resource(node, 'cim:PowerSystemResource.PSRType');
ele.container = get_resource(node, 'cim:Equipment.EquipmentContainer');
end

function ele = get_power_transformer_info(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.transformer_tank_info = get_resource(node, 'cim:PowerTransformerInfo.TransformerTankInfo');
end

function ele = get_psr_type(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
end

function ele = get_ratio_tap_changer(node)
ele = get_id(node);
ele.neutral_step = get_data(node, 'cim:TapChanger.neutralStep');
ele.high_step = get_data(node, 'cim:TapChanger.highStep');
ele.normal_step = get_data(node, 'cim:TapChanger.normalStep');
ele.ltc_flag = get_data(node, 'cim:TapChanger.ltcFlag');
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.low_step = get_data(node, 'cim:TapChanger.lowStep');
ele.step_voltage_increment = get_data(node, 'cim:RatioTapChanger.stepVoltageIncrement');
ele.psr_type = get_resource(node, 'cim:PowerSystemResource.PSRType');
ele.neutral_u = get_resource(node, 'cim:TapChanger.neutralU');
ele.transformer_end = get_resource(node, 'cim:RatioTapChanger.TransformerEnd');
end

function ele = get_substation(node)
ele = get_id(node);
ele.alias_name = get_data(node, 'cim:IdentifiedObject.aliasName');
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.psr_type = get_resource(node, 'cim:PowerSystemResource.PSRType');
end

function ele = get_switch_info(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
end

function ele = get_switch_phase(node)
ele = get_id(node);
ele.normal_open = get_data(node, 'cim:SwitchPhase.normalOpen');
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.phase_side1 = get_resource(node, 'cim:SwitchPhase.phaseSide1');
ele.phase_side2 = get_resource(node, 'cim:SwitchPhase.phaseSide2');
ele.switch = get_resource(node, 'cim:SwitchPhase.Switch');
end

function ele = get_terminal(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.sequence_number = get_data(node, 'cim:Terminal.sequenceNumber');
ele.phases = get_resource(node, 'cim:Terminal.phases');
ele.connectivity_node = get_resource(node, 'cim:Terminal.ConnectivityNode');
ele.conducting_equipment = get_resource(node, 'cim:Terminal.ConductingEquipment');
end

function ele = get_transformer_end_info(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.end_number = get_data(node, 'cim:TransformerEndInfo.endNumber');
end

function ele = get_transformer_tank(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.power_transformer = get_resource(node, 'cim:TransformerTank.PowerTransformer');
end

function ele = get_transformer_tank_end(node)
ele = get_id(node);
ele.end_number = get_data(node, 'cim:TransformerEnd.endNumber');
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.phases = get_resource(node, 'cim:TransformerTankEnd.phases');
ele.transformer_tank = get_resource(node, 'cim:TransformerTankEnd.TransformerTank');
ele.terminal = get_resource(node, 'cim:TransformerEnd.Terminal');
ele.base_voltage = get_resource(node, 'cim:TransformerEnd.BaseVoltage');
end

function ele = get_transformer_tank_info(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.power_transformer_info = get_resource(node, 'cim:TransformerTankInfo.PowerTransformerInfo');
end

function ele = get_usage_point(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.phase_code = get_resource(node, 'cim:UsagePoint.phaseCode');
ele.equipments = get_resource(node, 'cim:UsagePoint.Equipments');
end

function ele = get_voltage_level(node)
ele = get_id(node);
ele.name = get_data(node, 'cim:IdentifiedObject.name');
ele.base_voltage = get_resource(node, 'cim:VoltageLevel.BaseVoltage');
ele.substation = get_resource(node, 'cim:VoltageLevel.Substation');
end




