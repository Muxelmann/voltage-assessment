function save( self )
if isempty(self.output_dir)
    warning('Did not save because no output dir was set');
    return
end
cim = self;
save(fullfile(self.output_dir, 'cim_class.mat'), 'cim');
end