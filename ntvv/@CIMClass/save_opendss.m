function [ self ] = save_opendss( self )

% Clear all DSS element counts
self.dss_ele = [];

% Then clear the OpenDSS output directory
fclose('all');
out_dir_content = dir(fullfile(self.output_dir, '*.dss'));
for i = 1:length(out_dir_content)
    delete(fullfile(out_dir_content(i).folder, out_dir_content(i).name));
end


%% To begin converting, find the substation 
ss = self.get_elements_by_tag('cim:Substation');
assert(isempty(ss) == 0, ...
    'CIMClass:parse_element_tree:substation-count', ...
    [num2str(length(ss)) ' substations found']);
if length(ss) > 1
    warning([num2str(length(ss)) ' substations found']);
end
ss = ss{1};

% Find connectivity node that is part of substation (i.e. root node)
ss_cn = self.get_elements_by_resource(ss.id, 'cim:ConnectivityNode');
assert(length(ss_cn) == 1, ...
    'CIMClass:parse_element_tree:substation-connectivity-node', ...
    [num2str(length(ss_cn)) ' connectivity nodes found at substation']);
ss_cn = ss_cn{1};

%% Write the beginning of the master file

fid = fopen(fullfile(self.output_dir, 'master.dss'), 'a');
fprintf(fid, [...
    'Clear\n\nSet DefaultBaseFrequency=50.0\n\nNew Circuit.' ss.name ...
    '\n\nEdit Vsource.Source Bus1=' ss_cn.name ...
    ' BasekV=11.0 Frequency=50.0\n\n']);
fclose(fid);

%% Start the network parsing process

% Initialise CN list
cn_list = {ss_cn};
cn_old = {};

terminal_list = {};
terminal_old = {};

saved_equipment = {};

tic;
while isempty(cn_list) == 0
    cn_next = cn_list{1};
    cn_list(1) = [];
    cn_old{end+1} = cn_next;
    
    terminal_new = self.get_elements_by_resource(cn_next.id, 'cim:Terminal');
    terminal_new = self.remove_elements_from_set(terminal_old, terminal_new);
    
    if exist('terminal_list', 'var') == 0
        terminal_list = terminal_new;
    elseif isempty(terminal_list)
        terminal_list = terminal_new;
    else
        terminal_list = [terminal_list; terminal_new];
    end
    
    while isempty(terminal_list) == 0
        terminal_next = terminal_list{1};
        terminal_list(1) = [];
        terminal_old{end+1} = terminal_next;
        
        % Find conducting equipment
        equipment = self.get_element_by_id(terminal_next.conducting_equipment);
        [ cn_new, terminal_equipment ] = self.save_opendss_for_equipment(equipment);
        
        terminal_equipment = self.remove_elements_from_set(terminal_old, terminal_equipment);
        terminal_old = [terminal_old; terminal_equipment];
        
        cn_new = self.remove_elements_from_set(cn_old, cn_new);
        
        if exist('cn_list', 'var') == 0
            cn_list = cn_new;
        elseif isempty(cn_list)
            cn_list = cn_new;
        else
            cn_list = [cn_list; cn_new];
        end
    end
end

%% Finish by redirecting the master and adding voltage levels

dss_redirect_files = dir(fullfile(self.output_dir, '*.dss'));
ignore_idx = arrayfun(@(x) strcmp(x.name, 'master.dss'), dss_redirect_files);
dss_redirect_files(ignore_idx) = [];
ignore_idx = arrayfun(@(x) strcmp(x.name, 'buscoords.dss'), dss_redirect_files);
dss_coordinates = dss_redirect_files(ignore_idx);
dss_redirect_files(ignore_idx) = [];

fid = fopen(fullfile(self.output_dir, 'master.dss'), 'a');
for i = 1:length(dss_redirect_files)
    fprintf(fid, ['Redirect ' dss_redirect_files(i).name '\n']);
end
fprintf(fid, '\nSet voltagebases=[0.24, 0.4, 11.0]\nCalcvoltagebases\n');
fprintf(fid, ['\nBuscoords ' dss_coordinates.name '\n']);
fprintf(fid, '\nset markTransformers=yes\n');
fclose(fid);

disp('Finished DSS conversion');
end
