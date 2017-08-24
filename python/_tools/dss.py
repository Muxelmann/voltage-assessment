import _tools.opendssdirect as dss
import numpy as np
import pandas as pd


class DSSClass:

    _startup = False
    _load_count_original = 0
    _load_count_added = 0

    _load_shapes = []
    _load_shape_interval = 0.5


    @property
    def startup(self):
        return self._startup

    def __init__(self, master_path=None):
        self._startup = dss.Basic.Start() == 1
        if not self._startup:
            return
        dss.Basic.ClearAll()

        # Only continue if a circuit is passed
        if master_path is None:
            return
        # Load circuit
        dss.run_command('compile {}'.format(master_path))
        self._load_count_original = dss.Loads.Count()
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
        dss.run_command('new EnergyMeter.mater1 Element={} Terminal=1'.format(l_name))

        dss.Solution.Mode(1)
        dss.Solution.Number(1440)
        dss.Solution.StepSize(60)
        dss.run_command('Set mode=daily number=1440 stepsize=60s')
        print('SIM MODE: {} {}s #{}'.format(dss.Solution.Mode(), dss.Solution.StepSize(), dss.Solution.Number()))

        for load_name in dss.utils.Iterator(dss.Loads, 'Name'):
            dss.run_command(
                'new Monitor.mon_{}_vi Element=Load.{} Terminal=1 Mode=0'.format(load_name(), load_name()))
            dss.run_command(
                'new Monitor.mon_{}_pq Element=Load.{} Terminal=1 Mode=1'.format(load_name(), load_name()))

    def __repr__(self):
        if self.startup:
            did_start = 'started'
        else:
            did_start = 'failed'
        return 'DSSClass({})'.format(did_start)

    def add_load(self, name, bus, phases):
        if name in dss.Loads.AllNames():
            raise NameError('Element Load.{} already exists'.format(name))

        neutral = phases[-1]
        for phase in phases[:-1]:
            load_name = '{}_{}'.format(name, phase)
            phase_name = '{}.{}'.format(phase, neutral)
            dss.run_command(
                'new Load.{} Phases=1 Bus={}.{} kV=0.24 kW=0 PF=1 Model=1'.format(load_name, bus, phase_name))
            self._load_count_added += 1

    def solve_circuit(self):
        dss.Solution.Solve()

        # if not quick and dss.Monitors.Count() > 0:
        #     dss.Monitors.SampleAll()

        print(dss.Monitors.Count())
        dss.Monitors.First()
        dss.Monitors.Next()

        print(dss.__version__)
        print(dss.Monitors.ByteStream())

        # dss.Monitors.Show()
        # print(dss.utils.monitors_to_dataframe(dss))

    @property
    def load_count(self):
        return dss.Loads.Count()

    def load_power(self, p):
        if np.size(p) == 1:
            p = np.repeat(1, self.load_count)

        if np.size(p) is not self.load_count:
            raise IndexError('Power values do not match')

        load_id = dss.Loads.First()
        while load_id > 0:
            dss.Loads.kW(p[load_id-1])
            load_id = dss.Loads.Next()

    @property
    def load_shapes(self):
        return self._load_shapes

    @load_shapes.setter
    def load_shapes(self, load_shape_paths):
        self._load_shapes = []
        if not isinstance(load_shape_paths, list) or len(load_shape_paths) < self.load_count:
            raise ValueError
        load_shape_paths = load_shape_paths[0:self.load_count]

        for load_shape_path in load_shape_paths:
            load_shape_name = load_shape_path.split('/')[-1].split('.')[0]
            # print('loading: {}'.format(load_shape_path))
            load_shape_mult = pd.read_csv(load_shape_path, header=None).values.round(4).flatten().tolist()
            load_shape_len = len(load_shape_mult)
            dss.run_command(
                'new LoadShape.{} Npts={} Interval={} Mult={} Pbase=0.0'.format(
                    load_shape_name, load_shape_len, self._load_shape_interval, load_shape_mult))
            self._load_shapes.append(load_shape_name)

        # print(dss.LoadShape.Count())
        # if dss.LoadShape.Count() > 0:
        #     ls_id = dss.LoadShape.First()
        #     while ls_id > 0:
        #         print('{} ; {} ; {}'.format(
        #             dss.LoadShape.Name(), dss.LoadShape.PBase(), dss.LoadShape.PMult()
        #         ))
        #         ls_id = dss.LoadShape.Next()

        load_id = dss.Loads.First()
        while load_id > 0:
            dss.Loads.Duty(self._load_shapes[load_id-1])
            load_id = dss.Loads.Next()

    @load_shapes.deleter
    def load_shapes(self):
        del self._load_shapes

    def line_power(self, name):
        line_id = dss.Circuit.SetActiveElement('Line.{}'.format(name))
        if line_id < 0:
            raise IndexError('Line.{} not found'.format(name))

        return np.array(dss.CktElement.Powers()).reshape((-1, 2))[:3, :].dot(np.array([1, 1j]))

    def bus_voltages(self):
        return np.array(dss.Circuit.AllBusVolts()[6:]).reshape((-1, 2)).dot(np.array((1, 1j))).reshape((-1, 3))
