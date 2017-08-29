classdef DSSClass < handle
    %DSSCLASS Simple class to interface with OpenDSS

    properties (Transient=true)
        debug_enabled = nan
        
        dss_text = []
        dss_object = []
        dss_circuit = []

        load_shapes = []

        original_bus_distances = []
    end

    methods
        function self = DSSClass(master_path, debug_enabled)
            %DSSCLASS Inidialises the DSSClass
            if exist('debug_enabled', 'var') == 0
                debug_enabled = false;
            end
            
            if debug_enabled == 1
                self.debug_enabled = true;
            else
                self.debug_enabled = false;
            end
            
            self.disp('> Initialising DSSClass');

            dss_object = actxserver('OpenDSSEngine.DSS');
            dss_start = dss_object.Start(0);

            if dss_start
                self.disp('> Initialisation successful');
            else
                assert(dss_start, ...
                    'DSSClass:DSSClass:initialisationFailed', ...
                    'OpenDSS could not be initialised');
            end
            
            self.dss_object.AllowForms = self.debug_enabled;
            self.dss_object = dss_object;
            self.dss_text = dss_object.Text;

            self.disp('> Loading Circuit');
            self.dss_text.Command = 'clear';

            pwd_pre_compile = pwd;
            self.dss_text.Command = ['compile "', master_path, '"'];
            cd(pwd_pre_compile);
            self.dss_text.Command = 'set Maxiterations=100';
            self.dss_circuit = dss_object.ActiveCircuit;

            % Disable all energy meters
            idx = self.dss_circuit.Meters.First;
            while idx > 0
                self.dss_circuit.ActiveElement.Enabled = false;
                idx = self.dss_circuit.Meters.Next;
            end
            % Disable all monitors
            idx = self.dss_circuit.Monitors.First;
            while idx > 0
                self.dss_circuit.ActiveElement.Enabled = false;
                idx = self.dss_circuit.Monitors.Next;
            end

            % Add meter at top of feeder
            assert(self.dss_circuit.Lines.First > 0, ...
                'DSSClass:DSSClass:topLineMissing', ...
                'Could not find first line.');
            line_name = self.dss_circuit.ActiveElement.Name;
            self.dss_text.Command = ['new EnergyMeter.meter_main Element=' line_name ' Terminal=1'];

            % Add monitors and empty loadshapes to loads
            idx = self.dss_circuit.Loads.First;
            while idx > 0
                load_name = self.dss_circuit.Loads.Name;
                self.dss_text.Command = ['new Monitor.mon_' load_name '_vi Element=Load.' load_name ' Terminal=1 Mode=0 VIpolar=yes'];
                self.dss_text.Command = ['new Monitor.mon_' load_name '_pq Element=Load.' load_name ' Terminal=1 Mode=1 Ppolar=no'];
                self.dss_text.Command = ['new LoadShape.shape_' load_name ' Npts=0 Mult=()'];
                self.dss_circuit.Loads.Daily = ['shape_' load_name];
                idx = self.dss_circuit.Loads.Next;
            end
            self.dss_circuit.Solution.SolveDirect();
            self.original_bus_distances = self.dss_circuit.AllBusDistances;
        end
        
        function disp(self, str)
            if self.debug_enabled
                disp(str);
            end
        end
        
        function set_load_shape(self, load_shapes, randomised)
            assert(size(load_shapes, 2) >= self.dss_circuit.Loads.Count, ...
                'DSSClass:set_load_shape', ...
                'Not enough load shapes for the amount of loads');

            if exist('randomised', 'var') == 0
                randomised = false;
            end
            if randomised
                load_shapes = load_shapes(:, randperm(size(load_shapes, 2)));
            end
            
            self.reset();

            idx = self.dss_circuit.Loads.First;
            while idx > 0
                load_name = self.dss_circuit.Loads.Name;
                load_mult = load_shapes(:, idx);
                self.dss_text.Command = ['edit LoadShape.shape_' load_name ' Npts=' num2str(length(load_mult(:))) ' Mult=(' sprintf('%f,', load_mult(1:end-1)) sprintf('%f', load_mult(end)) ')'];
                idx = self.dss_circuit.Loads.Next;
            end

            self.dss_circuit.Solution.Mode = 2;
            self.dss_circuit.Solution.Number = size(load_shapes, 1);
        end

        function load_count = get_load_count(self)
            load_count = self.dss_circuit.Loads.Count;
        end

        function reset(self)
            self.dss_circuit.Meters.ResetAll;
            self.dss_circuit.Monitors.ResetAll;
        end
        
        function converged = solve(self)
            self.dss_circuit.Solution.Solve;
            converged = self.dss_circuit.Solution.Converged;
            if converged
                self.disp('> Solution converged');
            else
                self.disp('> Solution did not converge');
            end
        end

        function [pq, vi] = get_monitor_data(self)
            idx = self.dss_circuit.Monitors.First;
            % Initialise the data_map structure
            pq = []; vi = [];
            while idx > 0
                % Get the monitor's data as a byte stream
                byte_stream = self.dss_circuit.Monitors.ByteStream;
                % Decode the byte stream into a struct of monitor data
                monitor_data = decode_monitor(self, byte_stream);
                % Add the monitor data to the data array
                if monitor_data.name(end-1:end) == 'pq'
                    pq = [pq, monitor_data];
                else
                    vi = [vi, monitor_data];
                end
                % Continue with next monitor
                idx = self.dss_circuit.Monitors.Next;
            end

            function monitor_data = decode_monitor(dss, byte_stream)
                %DECODE_MONITOR Decodes the monitor's bytestream into a struct

                monitor_data = [];

                signature = typecast(byte_stream(1:4), 'int32');
                assert(signature == 43756, ...
                    'DSSClass:save_monitor_data:decode_monitor:incorrectSignature', ...
                    'ByteStream did not contain expected signature');

                % Signature
                monitor_data.signature = signature;
                % Name
                monitor_data.name = dss.dss_circuit.Monitors.Name;
                % Version: 32-bit integer
                monitor_data.version = typecast(byte_stream(5:8), 'int32');
                % Recordsize: 32-bit integer (bytes each record)
                monitor_data.size = typecast(byte_stream(9:12), 'int32');
                % Mode: 32-bit integer (monitor mode)
                monitor_data.mode = typecast(byte_stream(13:16), 'int32');
                % Header String: 256-byte ANSI characters (fixed length)
                monitor_data.header = native2unicode(byte_stream(17:272));
                % Read Reacords
                % Channels repeat every m.size + 2 times (+2 for hour and sec records)
                out = typecast(byte_stream(273:end), 'single');
                out = reshape(out, monitor_data.size+2, [])';
                monitor_data.data = out;

            end
        end

        function [load_distances, load_names] = get_load_distances(self)
            % Identify to which meter the distance is measured
            [load_zones, load_names, meter_names] =  self.get_load_meters();
            load_distances = nan(length(load_names), 1);

            % Get all distances and names from  busses
            bus_distances = self.dss_circuit.AllBusDistances;
            bus_names = self.dss_circuit.AllBusNames;

            % Find meter distances
            meter_distance = nan(length(meter_names), 1);
            for i = 1:length(meter_names)
                self.dss_circuit.SetActiveElement(['EnergyMeter.' meter_names{i}]);
                bus_name = self.dss_circuit.ActiveElement.BusNames{1};
                bus_idx = cellfun(@(x) strcmp(x, bus_name), self.dss_circuit.AllBusNames);
                meter_distance(i) = self.original_bus_distances(bus_idx);
            end

            % Filter for loads only
            for i = 1:length(load_names)
                self.dss_circuit.SetActiveElement(['Load.' load_names{i}]);
                load_bus = strsplit(self.dss_circuit.ActiveElement.BusNames{1}, '.');
                [~, idx] = ismember(bus_names, load_bus{1});
                load_distances(i) = bus_distances(idx == 1);
                if load_zones(i) > 1
                    load_distances(i) = load_distances(i) + meter_distance(load_zones(i));
                end
            end
        end

        function put_esmu_at_bus(self, bus, explicit_neutral)

            if exist('explicit_neutral', 'var') == 0
                neutral = '0';
            elseif explicit_neutral
                neutral = '4';
            end

            load_name = 'esmu';

            for p = 1:3
                new_load = [load_name '_' num2str(p)];
                if any(cellfun(@(x) strcmp(x, new_load), self.dss_circuit.Loads.AllNames))
                    command = 'edit';
                else
                    command = 'new';
                end
                phasing = ['.' num2str(p) '.' num2str(neutral)];
                self.dss_text.Command = [command ' Load.' new_load ' bus1=' bus phasing ' Phases=1 kW=0.0'];
            end
            self.dss_text.Command = ['AddBusMarker Bus=' bus ' code=12 color=Blue size=1'];

            idx = self.dss_circuit.Lines.First;
            if any(cellfun(@(x) strcmp(x, new_load), self.dss_circuit.Monitors.AllNames))
                command = 'edit';
            else
                command = 'new';
            end
            while idx > 0
                if strcmp(self.dss_circuit.Lines.Bus1, bus)
                    self.dss_circuit.SetActiveBus(bus)
                    self.dss_text.Command = [command ' EnergyMeter.meter_' load_name ' Element=' self.dss_circuit.ActiveElement.Name ' Terminal=1'];
                    break
                end
                idx = self.dss_circuit.Lines.Next;
            end
            self.dss_circuit.Solution.SolveDirect();
        end

        function [load_zones, load_names, meter_names] =  get_load_meters(self)
            % Identify all end points down stream from the available meters
            % that lie within the corresponding energy zone

            % Find all branches that belong to the relevant meter
            meter_names = repmat({[]}, self.dss_circuit.Meters.Count, 1);
            all_branches = repmat({[]}, self.dss_circuit.Meters.Count, 1);

            idx = self.dss_circuit.Meters.First;
            while idx > 0
                meter_names{idx} = self.dss_circuit.Meters.Name;
                all_branches{idx} = self.dss_circuit.Meters.AllBranchesInZone;
                % meter_branches{idx} = self.dss_circuit.Meters.AllEndElements;
                idx = self.dss_circuit.Meters.Next;
            end

            % Identify the load's zones (1, 2, 3 etc) according to meter
            load_zones = nan(self.dss_circuit.Loads.Count, 1);
            load_names = self.dss_circuit.Loads.AllNames;

            for i = 1:length(all_branches)
                % Find all end busses of the metered branches
                end_busses = repmat({[]}, length(all_branches{i}), 2);
                for j = 1:length(all_branches{i})
                    self.dss_circuit.SetActiveElement(all_branches{i}{j});
                    end_busses(j, :) = self.dss_circuit.ActiveElement.BusNames;
                end
                % Remove all duplicates
                end_busses = unique(end_busses(:));

                % For the corresponding load, determine if it is connected
                % to a bus that belongs to the corresponding meter
                idx = self.dss_circuit.Loads.First;
                while idx > 0
                    load_bus = strsplit(self.dss_circuit.ActiveElement.BusNames{1}, '.');
                    load_bus = load_bus{1};
                    keep_idx = cell2mat(arrayfun(@(x) ...
                        strcmp(end_busses(x), load_bus).', ...
                        1:length(end_busses), 'uni', 0).');
                    if any(keep_idx > 0)
                        load_zones(idx) = i;
                    end
                    idx = self.dss_circuit.Loads.Next;
                end
            end
        end

        function down_stream_customers(self)
            load_zones = get_load_meters(self);

            zone_colors = {...
                'Green', 'Red', 'Yellow', 'Maroon', 'Olive', ...
                'Navy', 'Purple', 'Teal', 'Gray', 'Silver', 'Lime', ...
                'Fuchsia', 'Aqua', 'LtGray', 'DkGray'};

            idx = self.dss_circuit.Loads.First;
            while idx > 0
                bus_info = strsplit(self.dss_circuit.ActiveElement.BusNames{1}, '.');
                assert(load_zones(idx) <= length(zone_colors), ...
                    'DSSCLass:down_stream_customers:too-many-meters', ...
                    'Too many meters and not enough DSS colors.');
                color = zone_colors{load_zones(idx)};
                self.dss_text.Command = ['AddBusMarker Bus=' bus_info{1} ' code=5 color=' color ' size=10'];
                idx = self.dss_circuit.Loads.Next;
            end

            self.dss_text.Command = 'plot circuit';
        end
    end

end
