classdef CIMClass < handle
    %CIMCLASS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % All CIM elements
        ele = {};
        
        % All elements that will be written into OpenDSS files
    end
    
    methods
        function self = CIMClass()
            self.ele = {};
        end
        
        [ self ] = add_all_elements( self, xml_file )
        
    end
    
    methods (Static = true)
        [ element ] = get_cim_element( node );
    end
    
end

