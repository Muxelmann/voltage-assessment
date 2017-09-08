function [ cn, terminals ] = save_opendss_for_equipment( self, equipment )
%SAVE_OPENDSS_FOR_ELEMENT Saves element to OpenDSS file

switch equipment.tag
    case 'cim:ACLineSegment'
        [terminals, cn] = save_ac_line_segment(self, equipment);
    case 'cim:BusbarSection'
        [terminals, cn] = save_busbar_section(self, equipment);
    case 'cim:Disconnector'
        [terminals, cn] = save_disconnector(self, equipment);
    case 'cim:EnergyConsumer'
        [terminals, cn] = save_energy_consumer(self, equipment);
    case 'cim:EnergyServicePoint'
        [terminals, cn] = save_energy_service_point(self, equipment);
    case 'cim:Fuse'
        [terminals, cn] = save_fuse(self, equipment);
    case 'cim:LoadBreakSwitch'
        [terminals, cn] = save_load_break_switch(self, equipment);
    case 'cim:PowerTransformer'
        [terminals, cn] = save_power_transformer(self, equipment);
    otherwise
        [terminals, cn] = get_terminals(self, equipment);
        warning(['No idea how to save ', equipment.tag]);
end

end

function [terminals, cn] = get_terminals(self, equipment)
% Find the equipment's terminals
terminals = self.get_elements_by_resource(equipment.id, 'cim:Terminal');
% Populate the corresponding new connectivity nodes
cn = repmat({[]}, 1, length(terminals));
for i = 1:length(terminals)
    cn{i} = self.get_element_by_id(terminals{i}.connectivity_node, 'cim:ConnectivityNode');
end
% Make sure the terminals are ordered correctly
terminals_oder = cellfun(@(x) str2double(x.sequence_number), terminals);
terminals = terminals(terminals_oder);
cn = cn(terminals_oder);

end

function save_new_transformer(self, dss)

if isfield(self.dss_ele, 'transformer')
    self.dss_ele.transformer{end+1} = dss.wdg_bus{1};
else
    self.dss_ele.transformer = {dss.wdg_bus{1}};
end

dss.txfrmr_name = strcat('txfrmr_', num2str(length(self.dss_ele.transformer)));
fid = fopen(fullfile(self.output_dir, 'transformers.dss'), 'a');
fprintf(fid, [...
    'new Transformer.' dss.txfrmr_name ...
    ' windings=' num2str(dss.txfrmr_windings) ...
    ' xhl=' num2str(dss.txfrmr_xhl) ...
    ' basefreq=' num2str(dss.txfrmr_basefreq) ...
    ' sub=' dss.txfrmr_sub ...
    '\n']);
for i = 1:dss.txfrmr_windings
    if dss.wdg_conn{i}(1) == 'w'
        dss.wdg_bus{i} = [dss.wdg_bus{i} '.1.2.3.0'];
    else
        dss.wdg_bus{i} = [dss.wdg_bus{i} '.1.2.3'];
    end
    
    fprintf(fid, [...
        ' ~ Wdg=' num2str(i) ...
        ' Bus=' dss.wdg_bus{i} ...
        ' Conn=' dss.wdg_conn{i} ...
        ' Kv=' num2str(dss.wdg_kv(i)) ...
        ' Kva=' num2str(dss.wdg_kva(i)) ...
        ' rneut=' num2str(dss.wdg_rneut(i)) ...
        ' xneut=' num2str(dss.wdg_xneut(i)) ...
        '\n']);
end
fclose(fid);
end

function save_new_line(self, dss)
if isfield(self.dss_ele, 'line')
    self.dss_ele.line = self.dss_ele.line + 1;
else
    self.dss_ele.line = 1;
end

dss.line_name = strcat('line_', num2str(self.dss_ele.line));
dss.line_linecode = self.get_fixed_id(dss.line_linecode);

fid = fopen(fullfile(self.output_dir, 'lines.dss'), 'a');
fprintf(fid, [...
    'new Line.' dss.line_name ...
    ' bus1=' [dss.line_bus{1} '.1.2.3.0'] ...
    ' bus2=' [dss.line_bus{2} '.1.2.3.0'] ...
    ' Linecode=' dss.line_linecode ...
    ' Length=' num2str(dss.line_length) ...
    ' Phases=' num2str(dss.line_phases) ...
    '\n']);
fclose(fid);

% Also, save the linecode if it has not already been saved

if isfield(self.dss_ele, 'linecode') == 0
    self.dss_ele.linecode = {};
end

if any(cellfun(@(x) strcmp(x, dss.line_linecode), self.dss_ele.linecode)) == 0
    self.dss_ele.linecode{end+1} = dss.line_linecode;
    
    linecode = [];
    linecode.name = dss.line_linecode;
    if isfield(self.equipments, 'cable') == 1 && isfield(self.equipments.cable, linecode.name)
        linecode_info = self.equipments.cable.(linecode.name);
        linecode.r1 = linecode_info.PositiveSequenceResistance;
        linecode.x1 = linecode_info.PositiveSequenceReactance;
        linecode.r0 = linecode_info.ZeroSequenceResistance;
        linecode.x0 = linecode_info.ZeroSequenceReactance;
        linecode.normamps = linecode_info.NominalRating;
        linecode.emergamps = linecode_info.FourthRating;
    elseif isfield(self.equipments, 'overhead') == 1 && isfield(self.equipments.overhead, linecode.name)
        linecode_info = self.equipments.overhead.(linecode.name);
        linecode.r1 = linecode_info.PositiveSequenceResistance;
        linecode.x1 = linecode_info.PositiveSequenceReactance;
        linecode.r0 = linecode_info.ZeroSequenceResistance;
        linecode.x0 = linecode_info.ZeroSequenceReactance;
        linecode.normamps = linecode_info.NominalRating;
        linecode.emergamps = linecode_info.FourthRating;
    else
        warning(['Linecode with default specifications is being used for: ' linecode.name]);
        linecode.r1 = 0.4;
        linecode.x1 = 1.4;
        linecode.r0 = 0.4;
        linecode.x0 = 1.4;
        linecode.normamps = 100;
        linecode.emergamps = 120;
    end
    
    linecode.units = 'km';
    linecode.basefreq = 50.0;
    linecode.nphases = 3;
    
    fid = fopen(fullfile(self.output_dir, 'linecodes.dss'), 'a');
    fprintf(fid, [...
        'New Linecode.' linecode.name ...
        ' Nphases=' num2str(linecode.nphases) ...
        ' R1=' num2str(linecode.r1) ...
        ' X1=' num2str(linecode.x1) ...
        ' R0=' num2str(linecode.r0) ...
        ' X0=' num2str(linecode.x0) ...
        ' Units=' linecode.units ...
        ' BaseFreq=' num2str(linecode.basefreq) ...
        ' Normamps=' num2str(linecode.normamps) ...
        ' Emergamps=' num2str(linecode.emergamps) ...
        '\n']);
    fclose(fid);
    
end

end

function save_new_load(self, dss)
if isfield(self.dss_ele, 'load')
    self.dss_ele.load{end+1} = dss.load_name;
else
    self.dss_ele.load = {dss.load_name};
end

dss.load_name = strcat('load_', num2str(length(self.dss_ele.load)));
tmp = strsplit(dss.load_phases, '.');
tmp = strrep(tmp{end}, 'A', '.1');
tmp = strrep(tmp, 'B', '.2');
tmp = strrep(tmp, 'C', '.3');
tmp = strrep(tmp, 'N', '.0');
dss.load_bus = [dss.load_bus tmp];
dss.load_phases = sum(tmp(2:end) == '.');

fid = fopen(fullfile(self.output_dir, 'loads.dss'), 'a');
fprintf(fid, [...
    'New Load.' dss.load_name ...
    ' bus1=' dss.load_bus ...
    ' Phases=' num2str(dss.load_phases) ...
    ' Kv=' num2str(dss.load_voltage) ...
    ' Kw=' num2str(dss.load_power) ...
    ' Pf=' num2str(dss.load_pf) ...
    ' Model=' num2str(dss.load_model) ...
    '\n']);
fclose(fid);

end

function save_coordinates(self, buses, coords)

if isfield(self.dss_ele, 'buses') == 0
    self.dss_ele.buses = {};
end

for i = 1:length(buses)
    bus = buses{i};
    if any(cellfun(@(x) strcmp(x, bus), self.dss_ele.buses))
        continue
    else
        self.dss_ele.buses{end+1} = bus;
    end
    
    fid = fopen(fullfile(self.output_dir, 'buscoords.dss'), 'a');
    fprintf(fid, '%s, %.10f, %.10f\n', bus, coords(i, 1), coords(i, 2));
    fclose(fid);
end
end

function [terminals, cn] = save_power_transformer(self, equipment)
[terminals, cn] = get_terminals(self, equipment);
dss = [];

% Find transformer's buses
dss.wdg_bus = cellfun(@(x) x.name, cn, 'uni', 0);

% Find asset for transformer information
txfrmr_asset = self.get_elements_by_resource(equipment.id, 'cim:Asset');
assert(length(txfrmr_asset) == 1, ...
    'CIMClass:save_opendss_for_equipment:save_power_transformer:no-asset', ...
    ['Found ' num2str(length(txfrmr_asset)) ' for ' equipment.id]);
txfrmr_asset = txfrmr_asset{1};

% Find transformer information and save
txfrmr_info = self.get_element_by_id(txfrmr_asset.asset_info);
txfrmr_info_name = self.get_fixed_id(txfrmr_info.name);

if isfield(self.equipments, 'transformer') == 1 && isfield(self.equipments.transformer, txfrmr_info_name)
    txfrmr_info = self.equipments.transformer.(txfrmr_info_name);
    dss.wdg_kv = [txfrmr_info.PrimaryVoltageKVLL, txfrmr_info.SecondaryVoltageKVLL];
    dss.wdg_kva = [txfrmr_info.NominalRatingKVA, txfrmr_info.NominalRatingKVA];
    dss.wdg_conn = {'delta', 'wye'};
    dss.wdg_rneut = [txfrmr_info.PrimGroundingResistanceOhms, txfrmr_info.SecGroundingResistanceOhms];
    dss.wdg_xneut = [txfrmr_info.PrimGroundingReactanceOhms, txfrmr_info.SecGroundingReactanceOhms];
    dss.txfrmr_xhl = txfrmr_info.XR0Ratio;
else
    warning(['Transformer with default specifications is being used for: ' equipment.id]);
    dss.wdg_kv = [11.0, 0.4];
    dss.wdg_kva = [500.0, 500.0];
    dss.wdg_conn = {'delta', 'wye'};
    dss.wdg_rneut = [0.0, 0.0];
    dss.wdg_xneut = [0.0, 0.0];
    dss.txfrmr_xhl = 8.0;
end

dss.txfrmr_windings = 2;
dss.txfrmr_basefreq = 50.0;
dss.txfrmr_sub = 'y';

save_new_transformer(self, dss);
end

function [terminals, cn] = save_busbar_section(self, equipment)
[terminals, cn] = get_terminals(self, equipment);
dss = [];

dss.line_bus = cellfun(@(x) x.name, cn, 'uni', 0);
dss.line_length = 1e-4;
dss.line_linecode = 'DEFAULT';
dss.line_phases = 3;
dss.line_units = 'm';

save_new_line(self, dss);
if isfield(equipment, 'coords')
    save_coordinates(self, dss.line_bus, equipment.coords)
end
end

function [terminals, cn] = save_disconnector(self, equipment)
[terminals, cn] = get_terminals(self, equipment);
dss = [];

dss.line_bus = cellfun(@(x) x.name, cn, 'uni', 0);
dss.line_length = 1e-4;
dss.line_linecode = 'DEFAULT';
dss.line_phases = 3;
dss.line_units = 'm';

save_new_line(self, dss);
end

function [terminals, cn] = save_fuse(self, equipment)
[terminals, cn] = get_terminals(self, equipment);
dss = [];

dss.line_bus = cellfun(@(x) x.name, cn, 'uni', 0);
dss.line_length = 1e-4;
dss.line_linecode = 'DEFAULT';
dss.line_phases = 3;
dss.line_units = 'm';

save_new_line(self, dss);
end

function [terminals, cn] = save_load_break_switch(self, equipment)
[terminals, cn] = get_terminals(self, equipment);
dss = [];

dss.line_bus = cellfun(@(x) x.name, cn, 'uni', 0);
dss.line_length = 1e-4;
dss.line_linecode = 'DEFAULT';
dss.line_phases = 3;
dss.line_units = 'm';

save_new_line(self, dss);
end

function [terminals, cn] = save_ac_line_segment(self, equipment)
[terminals, cn] = get_terminals(self, equipment);
dss = [];

line_bus = cellfun(@(x) x.name, cn, 'uni', 0);
line_length = str2double(equipment.length);

% Find asset/s for line
line_asset = self.get_elements_by_resource(equipment.id, 'cim:Asset');

% Check if it's overhead (broken into wires) or underground (single cable)
switch equipment.psr_type
    case 'PSRType_Overhead'
        assert(length(line_asset) == 2 || length(line_asset) == 4, ...
            'CIMClass:save_opendss_for_equipment:save_ac_line_segment:no-overhead-asset', ...
            ['Found ' num2str(length(line_asset)) ' for overhead wire ' equipment.id ' should be 2']);
        cable_info = self.get_element_by_id(line_asset{1}.asset_info, 'cim:OverheadWireInfo');
    case 'PSRType_Underground'
        assert(length(line_asset) == 1, ...
            'CIMClass:save_opendss_for_equipment:save_ac_line_segment:no-underground-asset', ...
            ['Found ' num2str(length(line_asset)) ' for cable ' equipment.id ' should be 1']);
        cable_info = self.get_element_by_id(line_asset{1}.asset_info, 'cim:CableInfo');        
    otherwise
        warning(['Unknown PSR type ' equipment.psr_type ' for ' equipment.id]);
        cable_info = [];
        cable_info.name = 'DEFAULT';
end

dss.line_linecode = cable_info.name;
dss.line_phases = 3;
dss.line_units = 'm';

length_scale = sqrt(sum(diff(equipment.coords).^2, 2));
length_scale = length_scale / sum(length_scale);

for i = 1:size(equipment.coords, 1)-1
    % Extract pairs of buses for each line segment
    if i == 1
        dss.line_bus = line_bus(1);
        dss.line_bus{end+1} = [line_bus{1} '_' num2str(i)];
    elseif i == size(equipment.coords, 1)-1
        dss.line_bus = {[line_bus{1} '_' num2str(i-1)]};
        dss.line_bus{end+1} = line_bus{2};
    else
        dss.line_bus = {[line_bus{1} '_' num2str(i-1)]};
        dss.line_bus{end+1} = [line_bus{1} '_' num2str(i)];
    end
    % Scale the segment's length
    dss.line_length = length_scale(i) * line_length;
    % Save the line
    save_new_line(self, dss);
    % Extract coordinates
    coords = equipment.coords(i:i+1,:);
    % Save bus coordiconates
    save_coordinates(self, dss.line_bus, coords)
end
end

function [terminals, cn] = save_energy_service_point(self, equipment)
[terminals, cn] = get_terminals(self, equipment);
dss = [];

% Do nothing...

end

function [terminals, cn] = save_energy_consumer(self, equipment)
[terminals, cn] = get_terminals(self, equipment);
dss = [];

dss.load_name = equipment.name;
dss.load_bus = cn{1}.name;
dss.load_phases = terminals{1}.phases;
dss.load_power = 1.0;
dss.load_voltage = 0.23;
dss.load_pf = 0.95;
dss.load_model = 1;

save_new_load(self, dss)
end

function [terminals, cn] = save_unknown(self, equipment)
[terminals, cn] = get_terminals(self, equipment);
dss = [];

% FIXME:
% - if 2 terminals add dummy line,
% - if 1 terminal add dummy load add do nothing
end
