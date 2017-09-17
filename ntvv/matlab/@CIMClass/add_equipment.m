function [ self ] = add_equipment( self, csv_file )

if exist(csv_file, 'file') == 0
    warning([csv_file ' does not exist']);
    return 
end
%%
data = readtable(csv_file);
data.Properties.VariableNames{1} = 'ID';
data(:, strcmpi('comments', data.Properties.VariableNames)) = [];
data(:, strcmpi('favorite', data.Properties.VariableNames)) = [];


equipment = [];
for i = 1:size(data, 1)
    tmp = [];
    for j = 2:length(data.Properties.VariableNames)
        tmp.(data.Properties.VariableNames{j}) = data{i, j};
    end
    field_name = self.get_fixed_id(data{i, 1}{1});
    equipment.(field_name) = tmp;
end

[~, file_name, ~] = fileparts(csv_file);
self.equipments.(file_name) = equipment;
end

