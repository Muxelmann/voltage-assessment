close all
clear
clc

all_cim_exports = dir(fullfile('CIM Export 31_03_2017 - confidential', 'CIM_Export*'));
root_output_dir = 'DSS Export - confidential';
cim_equipment = 'Equipment DB - confidential';

for i = 20:length(all_cim_exports)
    disp(all_cim_exports(i).name);
    cim_export = fullfile(all_cim_exports(i).folder, all_cim_exports(i).name);
    output_dir = fullfile(root_output_dir, strrep(all_cim_exports(i).name, 'CIM_', 'DSS_'));

    cim_converter(cim_export, cim_equipment, output_dir);
end