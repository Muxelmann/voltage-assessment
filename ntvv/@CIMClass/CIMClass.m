classdef CIMClass < handle
    %CIMCLASS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % All CIM elements
        ele = {};
        % All elements that will be written into OpenDSS directory
        output_dir = [];
        % All equipment properties
        equipments = {};
        % All OpenDSS Elements
        dss_ele = [];
    end
    
    properties (Transient = true)
        % Buffer for querying lists of elements
        ele_buffers = [];
    end
    
    methods
        function self = CIMClass( output_dir )
            
            if exist('output_dir', 'var') > 0 && exist(output_dir, 'dir') == 0
                mkdir(output_dir);
            end
            
            if exist(output_dir, 'dir') > 0
                self.output_dir = output_dir;
            end
            
            self.ele = {};
            self.ele_buffers = [];
            self.equipments = {};
            self.dss_ele = [];
        end
        
        save( self )
        
        [ self ] = load( self, input_path )
        
        [ self ] = add_equipment( self, csv_file )
        
        [ self ] = add_all_elements( self, xml_file )
        
        [ self ] = add_all_coordinates( self, xml_file )
        
        [ self ] = parse_element_tree( self )
        
        [ ele ] = get_elements_by_tag( self, tag, search_eles )
        
        [ ele ] = get_elements_by_resource( self, res, search_eles )
        
        [ ele, idx ] = get_element_by_id( self, id, search_eles )
        
        [ ele ] = remove_elements_from_set( self, remove_eles, search_eles )
        
        [ tags ] = get_string( self, search_eles )
        
        [ cn, terminals ] = save_opendss_for_equipment( self, equipment )
    end
    
    methods (Static = true)
        [ element ] = get_cim_element( node );
        
        [ element ] = get_cim_coordinates( node );
        
        [ field_name ] = get_fixed_id(string);
    end
    
end

