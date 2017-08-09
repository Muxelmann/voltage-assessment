import _tools.opendssdirect as dss
import numpy as np


class DSSClass:

    _startup = False
    _load_count_original = 0
    _load_count_added = 0

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
            dss.run_command('new Load.{} Phases=1 Bus={}.{} kV=0.24 kW=0 PF=1 Model=1'.format(load_name, bus, phase_name))
            self._load_count_added += 1

    def solve_circuit(self, quick=False):
        dss.Solution.Solve()

        if not quick and dss.Monitors.Count() > 0:
            dss.Monitors.SampleAll()

    @property
    def load_count(self):
        return dss.Loads.Count()

    def load_power(self, p):
        if np.size(p) == 1:
            p = np.repeat(1, dss.Loads.Count())

        if np.size(p) is not dss.Loads.Count():
            raise IndexError('Power values do not match')

        load_id = dss.Loads.First()
        while load_id > 0:
            dss.Loads.kW(p[load_id-1])
            load_id = dss.Loads.Next()

    def line_power(self, name):
        line_id = dss.Circuit.SetActiveElement('Line.{}'.format(name))
        if line_id < 0:
            raise IndexError('Line.{} not found'.format(name))

        return np.array(dss.CktElement.Powers()).reshape((-1, 2))[:3, :].dot(np.array([1, 1j]))

    def bus_voltages(self):
        return np.array(dss.Circuit.AllBusVolts()[6:]).reshape((-1, 2)).dot(np.array((1, 1j))).reshape((-1, 3))
