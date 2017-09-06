function self = load( self, input_path )
if exist('input_path', 'var') == 0
    input_path = fullfile(self.output_dir, 'cim_class.mat');
end

[~, ~, ext] = fileparts(input_path);

switch ext
    case '.mat'
        load(input_path);
        assert(exist('cim', 'var') == 1, ...
            'CIMClass:load:object-not-found', ...
            ['MAT file did not contain cim object: ' input_path]);
        
        
        assert(isa(cim, class(self)) == 1, ...
            'CIMClass:load:object-not-cim', ...
            ['cim object is not a CIMClass: ' input_path]);
        
        self = cim;
end

end