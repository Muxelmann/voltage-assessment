close all
clear

dss_master_path = dir('LVTestCase/Master.dss');
dss_data_dir = dir('Daily_1min_100profiles/*.txt');
data = [];
for i = 1:length(dss_data_dir)
    data_new = csvread(fullfile(dss_data_dir(i).folder, dss_data_dir(i).name));
    data = [data, data_new];
end

dss = DSSClass(fullfile(dss_master_path.folder, dss_master_path.name));
dss.set_load_shape(data);
dss.solve();

[pq, vi] = dss.get_monitor_data();

total_load = cell2mat(arrayfun(@(x) abs(pq(x).data(:,3:4) * [1; 1j]), 1:length(pq), 'uni', 0));

plot((1:1440)/60, sum(total_load, 2))

%%



