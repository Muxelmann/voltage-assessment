function [ ele ] = get_cim_element( node )

switch char(node.getNodeName)
    case 'cim:Asset'
        ele = get_asset(node);
    case 'cim:BaseVoltage'
        ele = get_base_voltage(node);
    case 'cim:Bay'
        ele = get_bay(node);
    case 'cim:BusbarSection'
        ele = get_busbar_section(node);
    case 'cim:BusbarSectionInfo'
        ele = get_busbar_section_info(node);
    case 'cim:ConnectivityNode'
        ele = get_connectivity_node(node);
    case 'cim:Disconnector'
        ele = get_disconnector(node);
    case 'cim:Fuse'
        ele = get_fuse(node);
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
end

function ele = get_asset(node)
ele = get_id(node);
ele.type = char(node.getElementsByTagName('cim:Asset.type').item(0).getChildNodes.item(0).getData);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);

psr = node.getElementsByTagName('cim:Asset.PowerSystemResources');
ele.power_system_resource = {};
for i = 1:psr.getLength
    ele.power_system_resource{end+1} = char(psr.item(i-1).getAttribute('rdf:resource'));
    ele.power_system_resource{end} = ele.power_system_resource{end}(2:end);
end

ele.asset_info = char(node.getElementsByTagName('cim:Asset.AssetInfo').item(0).getAttribute('rdf:resource'));
ele.asset_info = ele.asset_info(2:end);
end

function ele = get_base_voltage(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.base_voltage = char(node.getElementsByTagName('cim:BaseVoltage.nominalVoltage').item(0).getChildNodes.item(0).getData);
end

function ele = get_bay(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.substation = char(node.getElementsByTagName('cim:Bay.Substation').item(0).getAttribute('rdf:resource'));
ele.substation = ele.substation(2:end);
ele.voltage_level = char(node.getElementsByTagName('cim:Bay.VoltageLevel').item(0).getAttribute('rdf:resource'));
ele.voltage_level = ele.voltage_level(2:end);
end

function ele = get_busbar_section(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
if node.getElementsByTagName('cim:PowerSystemResource.PSRType').getLength > 0
    ele.psr_type = char(node.getElementsByTagName('cim:PowerSystemResource.PSRType').item(0).getAttribute('rdf:resource'));
    ele.psr_type = ele.psr_type(2:end);
end
if node.getElementsByTagName('cim:ConductingEquipment.BaseVoltage').getLength > 0
    ele.voltage_base = char(node.getElementsByTagName('cim:ConductingEquipment.BaseVoltage').item(0).getAttribute('rdf:resource'));
    ele.voltage_base = ele.voltage_base(2:end);
end
if node.getElementsByTagName('cim:Equipment.EquipmentContainer').getLength > 0
    ele.equipment_container = char(node.getElementsByTagName('cim:Equipment.EquipmentContainer').item(0).getAttribute('rdf:resource'));
    ele.equipment_container = ele.equipment_container(2:end);
end
end

function ele = get_busbar_section_info(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
end

function ele = get_connectivity_node(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.container = char(node.getElementsByTagName('cim:ConnectivityNode.ConnectivityNodeContainer').item(0).getAttribute('rdf:resource'));
ele.container = ele.container(2:end);
end

function ele = get_disconnector(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.normal_open = char(node.getElementsByTagName('cim:Switch.normalOpen').item(0).getChildNodes.item(0).getData);
ele.psr_type = char(node.getElementsByTagName('cim:PowerSystemResource.PSRType').item(0).getAttribute('rdf:resource'));
ele.psr_type = ele.psr_type(2:end);
ele.base_voltage = char(node.getElementsByTagName('cim:ConductingEquipment.BaseVoltage').item(0).getAttribute('rdf:resource'));
ele.base_voltage = ele.base_voltage(2:end);
ele.equipment_container = char(node.getElementsByTagName('cim:Equipment.EquipmentContainer').item(0).getAttribute('rdf:resource'));
ele.equipment_container = ele.equipment_container(2:end);
end

function ele = get_fuse(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.normal_open = char(node.getElementsByTagName('cim:Switch.normalOpen').item(0).getChildNodes.item(0).getData);
ele.psr_type = char(node.getElementsByTagName('cim:PowerSystemResource.PSRType').item(0).getAttribute('rdf:resource'));
ele.psr_type = ele.psr_type(2:end);
ele.base_voltage = char(node.getElementsByTagName('cim:ConductingEquipment.BaseVoltage').item(0).getAttribute('rdf:resource'));
ele.base_voltage = ele.base_voltage(2:end);
ele.equipment_container = char(node.getElementsByTagName('cim:Equipment.EquipmentContainer').item(0).getAttribute('rdf:resource'));
ele.equipment_container = ele.equipment_container(2:end);
end

function ele = get_power_transformer(node)
ele = get_id(node);
ele.alias_name = char(node.getElementsByTagName('cim:IdentifiedObject.aliasName').item(0).getChildNodes.item(0).getData);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.psr_type = char(node.getElementsByTagName('cim:PowerSystemResource.PSRType').item(0).getAttribute('rdf:resource'));
ele.psr_type = ele.psr_type(2:end);
ele.container = char(node.getElementsByTagName('cim:Equipment.EquipmentContainer').item(0).getAttribute('rdf:resource'));
ele.container = ele.container(2:end);
end

function ele = get_power_transformer_info(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.transformer_tank_info = char(node.getElementsByTagName('cim:PowerTransformerInfo.TransformerTankInfo').item(0).getAttribute('rdf:resource'));
ele.transformer_tank_info = ele.transformer_tank_info(2:end);
end

function ele = get_psr_type(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
end

function ele = get_ratio_tap_changer(node)
ele = get_id(node);
ele.neutral_step = char(node.getElementsByTagName('cim:TapChanger.neutralStep').item(0).getChildNodes.item(0).getData);
ele.high_step = char(node.getElementsByTagName('cim:TapChanger.highStep').item(0).getChildNodes.item(0).getData);
ele.normal_step = char(node.getElementsByTagName('cim:TapChanger.normalStep').item(0).getChildNodes.item(0).getData);
ele.ltc_flag = char(node.getElementsByTagName('cim:TapChanger.ltcFlag').item(0).getChildNodes.item(0).getData);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.low_step = char(node.getElementsByTagName('cim:TapChanger.lowStep').item(0).getChildNodes.item(0).getData);
ele.step_voltage_increment = char(node.getElementsByTagName('cim:RatioTapChanger.stepVoltageIncrement').item(0).getChildNodes.item(0).getData);
ele.psr_type = char(node.getElementsByTagName('cim:PowerSystemResource.PSRType').item(0).getAttribute('rdf:resource'));
ele.psr_type = ele.psr_type(2:end);
ele.neutral_u = char(node.getElementsByTagName('cim:TapChanger.neutralU').item(0).getAttribute('rdf:resource'));
ele.neutral_u = ele.neutral_u(2:end);
ele.transformer_end = char(node.getElementsByTagName('cim:RatioTapChanger.TransformerEnd').item(0).getAttribute('rdf:resource'));
ele.transformer_end = ele.transformer_end(2:end);
end

function ele = get_substation(node)
ele = get_id(node);
ele.alias_name = char(node.getElementsByTagName('cim:IdentifiedObject.aliasName').item(0).getChildNodes.item(0).getData);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.psr_type = char(node.getElementsByTagName('cim:PowerSystemResource.PSRType').item(0).getAttribute('rdf:resource'));
ele.psr_type = ele.psr_type(2:end);
end

function ele = get_switch_info(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
end

function ele = get_switch_phase(node)
ele = get_id(node);
ele.normal_open = char(node.getElementsByTagName('cim:SwitchPhase.normalOpen').item(0).getChildNodes.item(0).getData);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.phase_side1 = char(node.getElementsByTagName('cim:SwitchPhase.phaseSide1').item(0).getAttribute('rdf:resource'));
ele.phase_side1 = ele.phase_side1(2:end);
ele.phase_side2 = char(node.getElementsByTagName('cim:SwitchPhase.phaseSide2').item(0).getAttribute('rdf:resource'));
ele.phase_side2 = ele.phase_side2(2:end);
ele.switch = char(node.getElementsByTagName('cim:SwitchPhase.Switch').item(0).getAttribute('rdf:resource'));
ele.switch = ele.switch(2:end);
end

function ele = get_terminal(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.sequence_number = char(node.getElementsByTagName('cim:Terminal.sequenceNumber').item(0).getChildNodes.item(0).getData);
ele.phases = char(node.getElementsByTagName('cim:Terminal.phases').item(0).getAttribute('rdf:resource'));
ele.phases = ele.phases(2:end);
ele.connectivity_node = char(node.getElementsByTagName('cim:Terminal.ConnectivityNode').item(0).getAttribute('rdf:resource'));
ele.connectivity_node = ele.connectivity_node(2:end);
ele.conducting_equipment = char(node.getElementsByTagName('cim:Terminal.ConductingEquipment').item(0).getAttribute('rdf:resource'));
ele.conducting_equipment = ele.conducting_equipment(2:end);

end

function ele = get_transformer_end_info(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.end_number = char(node.getElementsByTagName('cim:TransformerEndInfo.endNumber').item(0).getChildNodes.item(0).getData);
end

function ele = get_transformer_tank(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.power_transformer = char(node.getElementsByTagName('cim:TransformerTank.PowerTransformer').item(0).getAttribute('rdf:resource'));
ele.power_transformer = ele.power_transformer(2:end);
end

function ele = get_transformer_tank_end(node)
ele = get_id(node);
ele.end_number = char(node.getElementsByTagName('cim:TransformerEnd.endNumber').item(0).getChildNodes.item(0).getData);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.phases = char(node.getElementsByTagName('cim:TransformerTankEnd.phases').item(0).getAttribute('rdf:resource'));
ele.phases = ele.phases(2:end);
ele.transformer_tank = char(node.getElementsByTagName('cim:TransformerTankEnd.TransformerTank').item(0).getAttribute('rdf:resource'));
ele.transformer_tank = ele.transformer_tank(2:end);
ele.terminal = char(node.getElementsByTagName('cim:TransformerEnd.Terminal').item(0).getAttribute('rdf:resource'));
ele.terminal = ele.terminal(2:end);
ele.base_voltage = char(node.getElementsByTagName('cim:TransformerEnd.BaseVoltage').item(0).getAttribute('rdf:resource'));
ele.base_voltage = ele.base_voltage(2:end);
end

function ele = get_transformer_tank_info(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.power_transformer_info = char(node.getElementsByTagName('cim:TransformerTankInfo.PowerTransformerInfo').item(0).getAttribute('rdf:resource'));
ele.power_transformer_info = ele.power_transformer_info(2:end);
end

function ele = get_voltage_level(node)
ele = get_id(node);
ele.name = char(node.getElementsByTagName('cim:IdentifiedObject.name').item(0).getChildNodes.item(0).getData);
ele.base_voltage = char(node.getElementsByTagName('cim:VoltageLevel.BaseVoltage').item(0).getAttribute('rdf:resource'));
ele.base_voltage = ele.base_voltage(2:end);
ele.substation = char(node.getElementsByTagName('cim:VoltageLevel.Substation').item(0).getAttribute('rdf:resource'));
ele.substation = ele.substation(2:end);
end




