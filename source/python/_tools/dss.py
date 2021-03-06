import _tools.opendssdirect as dss
import numpy as np


class DSSClass:
	_debug_enabled = True
	_startup = False

	_original_bus_distances = list()

	_load_shapes = list()
	_load_shape_interval = 60

	def __init__(self, master_path=None, debug_enabled=False):
		"""Initialises the OpenDSS and links it to DSSClass"""
		self._debug_enabled = debug_enabled
		if self._debug_enabled is not True:
			dss.Basic.AllowForms(False)

		self._print('> Initialising DSSClass')
		self._startup = dss.Basic.Start() == 1
		if not self._startup:
			return
		self._print('> Initialisation successful')

		self._print('> Loading circuit')
		# Only continue if a circuit is passed
		if master_path is None:
			return
		# Load circuit
		dss.Basic.ClearAll()
		dss.run_command('compile {}'.format(master_path))
		dss.run_command('set Maxiterations=100')

		# Disable all old meters and monitors
		e_id = dss.Meters.First()
		while e_id > 0:
			dss.CktElement.Enabled(False)
			e_id = dss.Meters.Next()
		m_id = dss.Monitors.First()
		while m_id > 0:
			dss.CktElement.Enabled(False)
			m_id = dss.Monitors.Next()

		# Add only a single energy meter to 1st line (hopefully top)
		dss.Lines.First()
		l_name = dss.CktElement.Name()
		dss.run_command('new EnergyMeter.mater_main Element={} Terminal=1'.format(l_name))

		idx = dss.Transformers.First()
		while idx > 0:
			txfrmr_name = dss.Transformers.Name()
			dss.run_command(
				'new Monitor.txfrmr_mon_{}_vi Element=Transformer.{} Terminal=1 Mode=0 VIpolar=yes'.format(txfrmr_name, txfrmr_name))
			dss.run_command(
				'new Monitor.txfrmrmon_{}_pq Element=Transformer.{} Terminal=1 Mode=1 Ppolar=no'.format(txfrmr_name, txfrmr_name))
			idx = dss.Transformers.Next()

		idx = dss.Loads.First()
		# for load_name in dss.utils.Iterator(dss.Loads, 'Name'):
		while idx > 0:
			load_name = dss.Loads.Name()
			dss.run_command(
				'new Monitor.load_mon_{}_vi Element=Load.{} Terminal=1 Mode=0 VIpolar=yes'.format(load_name, load_name))
			dss.run_command(
				'new Monitor.load_mon_{}_pq Element=Load.{} Terminal=1 Mode=1 Ppolar=no'.format(load_name, load_name))
			# dss.run_command('new LoadShape.shape_{} Npts=0 Mult=()'.format(load_name))
			# dss.Loads.Daily('shape_{}'.format(load_name))
			idx = dss.Loads.Next()
		dss.Solution.SolveDirect()
		self._original_bus_distances = dss.Circuit.AllBusDistances()

	def __repr__(self):
		"""Returns the DSSClass descriptor string"""
		if self._startup:
			did_start = 'started'
		else:
			did_start = 'failed'
		return 'DSSClass({})'.format(did_start)

	def _print(self, *args, **kwargs):
		"""Internal print function that only outputs to console if debug is enabled"""
		if self._debug_enabled:
			print(*args, **kwargs)

	def set_load_shapes(self, load_shapes, randomised=False):
		"""Sets a loadshape matrix [T x N] of T time steps and N loads"""
		if np.size(load_shapes, 1) < self.load_count():
			return

		if randomised:
			load_shapes = load_shapes[:, np.random.permutation(np.size(load_shapes, 1))]

		# self.reset()
		# idx = dss.Loads.First()
		# while idx > 0:
		#	 load_name = dss.Loads.Name()
		#	 load_mult = load_shapes[:, idx-1]
		#	 cmd = 'edit LoadShape.shape_{} Npts={} Mult={}'.format(load_name, load_mult.size, load_mult.tolist())
		#	 dss.run_command(cmd)
		#	 idx = dss.Loads.Next()
		#
		# dss.Solution.Mode(2)
		# dss.Solution.Number(np.size(load_shapes, 0))

		self._load_shapes = load_shapes[:, 0:self.load_count()]

	def load_count(self):
		"""Returns the number of loads in circuit"""
		return dss.Loads.Count()

	def reset(self):
		"""Resets both meter and monitor data"""
		dss.Meters.ResetAll()
		dss.Monitors.ResetAll()

	def solve(self):
		"""Runs the simulation as specified in loadshapes"""
		sim_length = np.size(self._load_shapes, 0)
		dss.Solution.Mode(0)

		for t in range(sim_length):
			dss.Solution.Hour(t * 60 // 3600)
			dss.Solution.Seconds(divmod(t * 60, 3600)[1])
			idx = dss.Loads.First()
			while idx > 0:
				dss.Loads.kW(self._load_shapes[t, idx - 1])
				idx = dss.Loads.Next()
			dss.Solution.Solve()
			dss.Monitors.SampleAll()

	def get_monitor_data(self, include='load_mon_'):
		"""Returns all monitors' data"""
		dss.Monitors.SaveAll()
		idx = dss.Monitors.First()
		pq = list()
		vi = list()
		while idx > 0:
			byte_stream = dss.Monitors.ByteStream()
			mon_name = dss.Monitors.Name()
			if include is not None and isinstance(include, str):
				if include not in mon_name:
					idx = dss.Monitors.Next()
					continue

			if '_pq' in mon_name:
				pq.append(byte_stream)
			else:
				vi.append(byte_stream)
			idx = dss.Monitors.Next()

		return pq, vi

	def put_load_at_bus(self, bus_name, load_name='esmu'):
		"""Adds a load of a given load name to a certain bus"""

		# Add one load per phase
		for p in range(3):
			new_load_name = '{}_{}'.format(load_name, p + 1)
			if new_load_name in dss.Loads.AllNames():
				command = 'edit'
			else:
				command = 'new'
			bus_with_phasing = '{}.{}.0'.format(bus_name, p + 1)
			dss.utils.run_command('{} Load.{} bus1={} Phases=1 kW=0.0'.format(command, new_load_name, bus_with_phasing))
			dss.utils.run_command('{} Monitor.load_mon_{}_vi Element=Load.{} Termina=1 Mode=0 VIpolar=yes'.format(command, new_load_name, new_load_name))
			dss.utils.run_command('{} Monitor.load_mon_{}_pq Element=Load.{} Termina=1 Mode=1 Ppolar=no'.format(command, new_load_name, new_load_name))

		# Add energy meter at new load
		new_meter_name = 'meter_{}'.format(load_name)
		if new_meter_name in dss.Meters.AllNames():
			command = 'edit'
		else:
			command = 'new'

		idx = dss.Lines.First()
		while idx > 0:
			if dss.Lines.Bus1() == bus_name:
				dss.utils.run_command(
					'{} EnergyMeter.{} Element={} Terminal=1'.format(command, new_meter_name, dss.CktElement.Name()))
				break
			idx = dss.Lines.Next()
		dss.Solution.SolveDirect()

	def get_load_phases(self):
		"""Returns the phases for each load name"""
		load_names = dss.Loads.AllNames()
		load_phases = dict()
		for load_name in load_names:
			if int(dss.Circuit.SetActiveElement('Load.{}'.format(load_name))) <= 0:
				load_names.remove(load_name)
				continue
			load_phases[load_name] = int(dss.CktElement.BusNames()[0].split('.')[1])

		return load_phases

	def get_load_meters(self):
		"""Returns the energy meter to which the corresponding load belongs"""
		# Obtain all branches that are part of the metered zone
		meter_names = list()
		meter_branches = list()
		idx = dss.Meters.First()
		while idx > 0:
			meter_names.append(dss.Meters.Name())
			meter_branches.append(dss.Meters.AllBranchesInZone())
			idx = dss.Meters.Next()

		# Find all buses of the branches
		meter_buses = dict()
		for i in range(len(meter_names)):
			buses = list()
			for conducting_element in meter_branches[i]:
				dss.Circuit.SetActiveElement(conducting_element)
				buses_new = dss.CktElement.BusNames()
				for bus in buses_new:
					if bus not in buses:
						buses.append(bus)
			meter_buses[meter_names[i]] = buses

		# For each load's bus, match which meter it belongs to
		load_meters = dict()
		idx = dss.Loads.First()
		while idx > 0:
			load_bus = dss.CktElement.BusNames()[0].split('.')[0]
			for meter_name in meter_buses.keys():
				if load_bus in meter_buses[meter_name]:
					load_meters[dss.Loads.Name()] = meter_name
					continue
			idx = dss.Loads.Next()

		return load_meters

	def get_load_meter_and_phase(self):
		load_phases = self.get_load_phases()
		load_meters = self.get_load_meters()

		load_info = dict()
		for load_name in load_phases.keys():
			load_info[load_name] = (load_meters[load_name], load_phases[load_name])
		return load_info

	def get_load_power_and_voltage(self):
		pq, vi = self.get_monitor_data()
		# pq = [l for l in pq if ]
		powers = np.abs(np.array([l['P1 (kW)'].as_matrix() + 1j * l['Q1 (kvar)'].as_matrix() for l in pq])).T
		voltages = np.abs(np.array([l['V1'].as_matrix() - l['V2'].as_matrix() for l in vi])).T
		return powers, voltages
