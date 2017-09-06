function [ self ] = parse_element_tree( self )

%% Fist find the substation

ss = self.get_elements_by_tag('cim:Substation');
assert(length(ss) == 1, ...
    'CIMClass:parse_element_tree:substation-count', ...
    [num2str(length(ss)) ' substations found']);
ss = ss{1};

% Find elememts that belong to the substation
ss_ele = self.get_elements_by_resource(ss.id);
% Find connectivity node that is part of substation
ss_cn = self.get_elements_by_tag('cim:ConnectivityNode', ss_ele);

assert(length(ss_cn) == 1, ...
    'CIMClass:parse_element_tree:substation-connectivity-node', ...
    [num2str(length(ss_cn)) ' connectivity nodes found at substation']);

% Found substation (i.e. root) connectivity node
ss_cn = ss_cn{1};

%% Step from one connectivity node to the next

% Initialise CN list
cn_list = {ss_cn};
cn_old = {};

terminal_list = {};
terminal_old = {};

saved_equipment = {};

while isempty(cn_list) == 0
    cn_next = cn_list{1};
    cn_list(1) = [];
    cn_old{end+1} = cn_next;
    
    terminal_new = self.get_elements_by_resource(cn_next.id, 'cim:Terminal');
    terminal_new = self.remove_elements_from_set(terminal_old, terminal_new);
    
    terminal_list = [terminal_list; terminal_new];
    
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
        
        if exist('cn_list', 'var')
            cn_list = [cn_list; cn_new];
        else
            cn_list = cn_new;
        end
    end
end

end


function [ cn_new, terminal_equipment ] = save_equipment_begind_terminal( self, terminal )

end