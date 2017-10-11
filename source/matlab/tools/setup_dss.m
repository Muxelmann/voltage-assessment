function [ dss, data ] = setup_dss( dss_master_path, esmu_loc, dss_data_dir )
%SETUP_DSS Sets up the OpenDSS link
%   _ = SETUP_DSS(dss_master_path) only starts DSS
%   _ = SETUP_DSS(dss_master_path, esmu_loc) adds ESMU at bus
%   _ = SETUP_DSS(dss_master_path, esmu_loc, dss_data_dir) also loads in CSVs
%   [dss] = SETUP_DSS() returns DSSClass object
%   [dss, data] = SETUP_DSS() also returns loaded data
%
%   See also DSSCLASS

dss = DSSClass(fullfile(dss_master_path.folder, dss_master_path.name));

% Add ESMU
if exist('esmu_loc', 'var') > 0
    dss.put_esmu_at_bus(esmu_loc);
end

% Get the load shapes
if exist('dss_data_dir', 'var') > 0
    data = [];
    for i = 1:length(dss_data_dir)
        data_new = csvread(fullfile(dss_data_dir(i).folder, dss_data_dir(i).name));
        data = [data, data_new];
    end
else
    data = [];
end

% dss.down_stream_customers();

% [load_distances, load_names] = dss.get_load_distances();
% plot(load_distances, 'x');
% hold on
% arrayfun(@(x) text(x, load_distances(x), load_names{x}, 'Rotation', -60), 1:length(load_distances));
% hold off

end

