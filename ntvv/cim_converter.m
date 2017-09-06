close all
clear
clc

cim_export = 'CIM Export 31_03_2017/CIM_Export_Binfield';


xml_files = dir([cim_export '/*.xml']);
gml_files = dir([cim_export '/*.gml']);


cim = CIMClass();
for i = 1:length(xml_files)
    xml_path = fullfile(xml_files(i).folder, xml_files(i).name);
    cim.add_all_elements(xml_path);
end

%%

cim.parse_element_tree();