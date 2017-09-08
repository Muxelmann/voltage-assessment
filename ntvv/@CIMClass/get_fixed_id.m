function [ field_name ] = get_fixed_id( string )

field_name = strrep(string, '.', '_');
field_name = strrep(field_name, '&', 'and');
field_name = strrep(field_name, ',', '');
field_name = strrep(field_name, '(', '');
field_name = strrep(field_name, ')', '');
field_name = strrep(field_name, '-', '_');
field_name = strrep(field_name, '=', '');
field_name = strrep(field_name, '''', '');
field_name = strrep(field_name, '*', 'x');
field_name = strrep(field_name, '/', 'or');
field_name = strrep(field_name, '>', '_gt');
field_name = strrep(field_name, '<', '_lt');

field_name = strcat('id_', field_name);

end

