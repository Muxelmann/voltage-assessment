classdef CIMClass < handle
    %CIMCLASS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % All CIM elements
        ele = {};
        % Buffer for querying lists of elements
        ele_buffers = [];
        % All elements that will be written into OpenDSS directory
        output_dir = [];
    end
    
    methods
        function self = CIMClass( output_dir )
            
            if exist('output_dir', 'var') == 1 && exist(output_dir, 'dir') == 0
                self.output_dir = output_dir;
                mkdir(output_dir);
            end
            
            self.ele = {};
            self.ele_buffers = [];
        end
        
        save( self )
        
        [ self ] = load( self, input_path )
        
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
    end
    
end

