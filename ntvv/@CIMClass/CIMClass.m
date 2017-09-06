classdef CIMClass < handle
    %CIMCLASS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % All CIM elements
        ele = {};
        % Buffer for querying lists of elements
        ele_buffers = [];
        
        % All elements that will be written into OpenDSS files
    end
    
    methods
        function self = CIMClass()
            self.ele = {};
            self.ele_buffers = [];
        end
        
        [ self ] = add_all_elements( self, xml_file )
        
        [ self ] = parse_element_tree( self )
        
        [ ele ] = get_elements_by_tag( self, tag, search_eles )
        
        [ ele ] = get_elements_by_resource( self, res, search_eles )
        
        [ ele ] = get_element_by_id( self, id, search_eles )
        
        [ ele ] = remove_elements_from_set( self, remove_eles, search_eles )
        
        [ tags ] = get_string( self, search_eles )
    end
    
    methods (Static = true)
        [ element ] = get_cim_element( node );
    end
    
end

