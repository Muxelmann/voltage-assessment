close all
clear
clc

cim_export = 'CIM Export 31_03_2017 - confidential/CIM_Export_Binfield';
cim_equipment = 'Equipment DB - confidential';
output_dir = 'DSS Export - confidential/Export_Binfield';

xml_files = dir(fullfile(cim_export, '*.xml'));
gml_files = dir(fullfile(cim_export, '*.gml'));
equ_files = dir(fullfile(cim_equipment, '*.csv'));

cim = CIMClass(output_dir);

%%
for i = 1:length(xml_files)
    xml_path = fullfile(xml_files(i).folder, xml_files(i).name);
    cim.add_all_elements(xml_path);
end

for i = 1:length(gml_files)
    gml_path = fullfile(gml_files(i).folder, gml_files(i).name);
    cim.add_all_coordinates(gml_path);
end

clc
for i = 1:length(equ_files)
    equ_path = fullfile(equ_files(i).folder, equ_files(i).name);
    cim.add_equipment(equ_path);
end
cim.save();

%%

cim.load();

clc
cim.parse_element_tree();