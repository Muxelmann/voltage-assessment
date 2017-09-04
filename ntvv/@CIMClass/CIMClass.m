classdef CIMClass < handle
    %CIMCLASS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % The main data structure
        ele_tree = []
        
        % All elements that will be written into OpenDSS files
        transformers = []
        lines = []
        loads = []
        buses = []
    end
    
    methods
        function self = CIMClass(xml_file)
            xml_data = xmlread(xml_file);
            self.ele_tree = parseChildNodes(xml_data);
            
            function children = parseChildNodes(theNode)
                % Recurse over node children.
                children = [];
                if theNode.hasChildNodes
                    childNodes = theNode.getChildNodes;
                    numChildNodes = childNodes.getLength;
                    allocCell = cell(1, numChildNodes);
                    
                    children = struct(             ...
                        'Name', allocCell, 'Attributes', allocCell,    ...
                        'Data', allocCell, 'Children', allocCell);
                    
                    for count = 1:numChildNodes
                        theChild = childNodes.item(count-1);
                        children(count) = makeStructFromNode(theChild);
                    end
                end
            end
            
            function nodeStruct = makeStructFromNode(theNode)
                % Create structure of node info.
                
                nodeStruct = struct(                        ...
                    'Name', char(theNode.getNodeName),       ...
                    'Attributes', parseAttributes(theNode),  ...
                    'Data', '',                              ...
                    'Children', parseChildNodes(theNode));
                
                if any(strcmp(methods(theNode), 'getData'))
                    nodeStruct.Data = char(theNode.getData);
                else
                    nodeStruct.Data = '';
                end
            end
            
            function attributes = parseAttributes(theNode)
                % Create attributes structure.
                
                attributes = [];
                if theNode.hasAttributes
                    theAttributes = theNode.getAttributes;
                    numAttributes = theAttributes.getLength;
                    allocCell = cell(1, numAttributes);
                    attributes = struct('Name', allocCell, 'Value', ...
                        allocCell);
                    
                    for count = 1:numAttributes
                        attrib = theAttributes.item(count-1);
                        attributes(count).Name = char(attrib.getName);
                        attributes(count).Value = char(attrib.getValue);
                    end
                end
            end
        end
        
        function txfrmr = find_all_transformers(self)
            self.transformers = [];
            
            txfrmr = self.get_children_named('cim:PowerTransformer');
            
            for txfrmr_i = 1:length(txfrmr)
                txfrmr_id = txfrmr.Attributes.Value;
                txfrmr_name = self.get_children_data('cim:IdentifiedObject.aliasName', txfrmr);
                
                txfrmr_terminals = self.get_children_containing('cim:Terminal', 'ConductingEquipment', txfrmr_id);
                txfrmr_tank_end = self.get_children_named('cim:TransformerTankEnd');
                    
                if isempty(self.transformers)
                    self.transformers = struct();
                else
                    self.transformers(end+1) = self.transformers(end);
                end
                self.transformers(end).name = txfrmr_name;
                self.transformers(end).windings_count = length(txfrmr_terminals);
                self.transformers(end).winding = repmat(struct(), length(txfrmr_terminals), 1);
                self.transformers(end).xhl = 8.0;
                self.transformers(end).basefreq = 50.0;
                
                for i = 1:length(txfrmr_terminals)
                    self.transformers(end).winding(i).number = str2double(self.get_children_data('cim:Terminal.sequenceNumber', txfrmr_terminals(i)));
                    
                    phasing = self.get_attribute_value('cim:Terminal.phases', txfrmr_terminals(i));
                    phasing = strsplit(phasing, '.');
                    phasing = phasing{end};
                    phasing = strrep(phasing, 'A', '1.');
                    phasing = strrep(phasing, 'B', '2.');
                    phasing = strrep(phasing, 'C', '3.');
                    if phasing(end) == 'N'
                        phasing = strrep(phasing, 'N', '.0');
                        self.transformers(end).winding(i).connection = 'delta';
                    else
                        phasing(end) = [];
                        self.transformers(end).winding(i).connection = 'wye';
                    end
                    self.transformers(end).winding(i).phasing = phasing;
                    
                    self.transformers(end).winding(i).bus = self.get_attribute_value('cim:Terminal.ConnectivityNode', txfrmr_terminals(i));
                    self.transformers(end).winding(i).bus = self.transformers(end).winding(i).bus(2:end);
                
                    terminal_id = txfrmr_terminals(i).Attributes.Value;
                    
                    voltage = self.get_attribute_value('cim:TransformerEnd.BaseVoltage', txfrmr_tank_end(1));
                    voltage = strsplit(voltage, '_');
                    self.transformers(end).winding(i).kv = str2double(voltage{end});
                end
                
                % Write all data to the transformer
                
            end
        end
    end
    
    methods (Access = public)
        function children = get_children_named(self, name, for_element)
            if exist('for_element', 'var') == 0
                for_element = self.ele_tree;
            end
            
            idx = cellfun(@(x) strcmp(x, name), {for_element.Children.Name});
            assert(any(idx), 'CIMClass:get_children_named:no-child-found', ...
                [name ' not found in XML tree']);
            children = for_element.Children(idx);
        end
        
        function data = get_children_data(self, name, for_element)
            if exist('for_element', 'var') == 0
                for_element = self.ele_tree;
            end
            
            children = self.get_children_named(name, for_element);
            if length(children) > 1
                data = {children.Children.Data};
            else
                data = children.Children.Data;
            end
        end
        
        function value = get_attribute_value(self, name, for_element)
            if exist('for_element', 'var') == 0
                for_element = self.ele_tree;
            end
            
            children = self.get_children_named(name, for_element);
            if length(children) > 1
                value = {children.Attributes.Value};
            else
                value = children.Attributes.Value;
            end
            
        end
        
        function children = get_children_containing(self, attribute, child_name, value, for_element)
            if exist('for_element', 'var') == 0
                for_element = self.ele_tree;
            end
            
            children = self.get_children_named(attribute, for_element);
            
            child_name = [attribute '.' child_name];
            for i = length(children):-1:1
                sub_children = self.get_children_named(child_name, children(i));
                if strcmp(sub_children.Attributes.Value(2:end), value) == 0
                    children(i) = [];
                end
            end
        end
        
    end
    
end

