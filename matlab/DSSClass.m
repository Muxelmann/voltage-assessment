classdef DSSClass
    %DSSCLASS Simple class to interface with OpenDSS
    
    properties (Transient=true)
        dss_text = []
        dss_object = []
        dss_circuit = []
        
        load_shapes = []
    end
    
    methods
        function self = DSSClass(master_path)
            %DSSCLASS Inidialises the DSSClass
            disp('> Initialising DSSClass');
            
            dss_object = actxserver('OpenDSSEngine.DSS');
            dss_start = dss_object.Start(0);
            
            if dss_start
                disp(' > Initialisation successful');
            else
                assert(dss_start, ...
                    'DSSClass:DSSClass:initialisationFailed', ...
                    'OpenDSS could not be initialised');
            end
            
            self.dss_object = dss_object;
            self.dss_text = dss_object.Text;
            
            disp('> Loading Circuit');
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
            self.dss_text.Command = ['new EnergyMeter.mater1 Element=' line_name ' Terminal=1'];
            
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
            
            self.dss_circuit.Meters.ResetAll
            self.dss_circuit.Monitors.ResetAll
            
            idx = self.dss_circuit.Loads.First;
            while idx > 0
                load_name = self.dss_circuit.Loads.Name;
                load_mult = load_shapes(:, idx);
                self.dss_text.Command = ['new LoadShape.shape_' load_name ' Npts=' num2str(length(load_mult(:))) ' Mult=(' sprintf('%f,', load_mult(1:end-1)) sprintf('%f', load_mult(end)) ')'];
%                 self.dss_circuit.Loads.Daily = ['shape_' load_name];
                idx = self.dss_circuit.Loads.Next;
            end
            
            self.dss_circuit.Solution.Mode = 2;
            self.dss_circuit.Solution.Number = size(load_shapes, 1);
        end
        
        function load_count = get_load_count(self)
            load_count = self.dss_circuit.Loads.Count;
        end
        
        function solve(self)
            self.dss_circuit.Solution.Solve();
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
            load_names = self.dss_circuit.Loads.AllNames;
            load_distances = nan(length(load_names), 1);
            bus_names = self.dss_circuit.AllBusNames;
            bus_distances = self.dss_circuit.AllBusDistances;
            for i = 1:length(load_names)
                self.dss_circuit.SetActiveElement(['Load.' load_names{i}]);
                load_bus = strsplit(self.dss_circuit.ActiveElement.BusNames{1}, '.');
                [~, idx] = ismember(bus_names, load_bus{1});
                load_distances(i) = bus_distances(idx == 1);
            end
        end
    end
    
end

