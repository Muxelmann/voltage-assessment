import _tools.opendssdirect as dss
import numpy as np


class DSSClass:

    _startup = False

    _load_shapes = []
    _load_shape_interval = 0.5

    def __init__(self, master_path=None):
        print('> Initialising DSSClass')
        self._startup = dss.Basic.Start() == 1
        if not self._startup:
            return
        print('> Initialisation successful')

        print('> Loading circuit')
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

        idx = dss.Loads.First()
        # for load_name in dss.utils.Iterator(dss.Loads, 'Name'):
        while idx > 0:
            load_name = dss.Loads.Name()
            dss.run_command(
                'new Monitor.mon_{}_vi Element=Load.{} Terminal=1 Mode=0'.format(load_name, load_name))
            dss.run_command(
                'new Monitor.mon_{}_pq Element=Load.{} Terminal=1 Mode=1'.format(load_name, load_name))
            dss.run_command('new LoadShape.shape_{} Npts=0 Mult=()'.format(load_name))
            dss.Loads.Daily('shape_{}'.format(load_name))
            idx = dss.Loads.Next()
        dss.Solution.SolveDirect()
        self._original_bus_distances = dss.Circuit.AllBusDistances()

    def __repr__(self):
        if self._startup:
            did_start = 'started'
        else:
            did_start = 'failed'
        return 'DSSClass({})'.format(did_start)

    def set_load_shapes(self, load_shapes, randomised=False):
        if np.size(load_shapes, 1) < dss.Loads.Count():
            return

        if randomised:
            load_shapes = load_shapes[:, np.random.permutation(np.size(load_shapes, 1))]

        dss.Meters.ResetAll()
        dss.Monitors.ResetAll()

        idx = dss.Loads.First()
        while idx > 0:
            load_name = dss.Loads.Name()
            load_mult = load_shapes[:, idx-1]
            cmd = 'edit LoadShape.shape_{} Npts={} Mult={}'.format(load_name, load_mult.size, load_mult.tolist())
            dss.run_command(cmd)
            idx = dss.Loads.Next()

        dss.Solution.Mode(2)
        dss.Solution.Number(np.size(load_shapes, 0))

    def load_count(self):
        return dss.Loads.Count()

    def solve(self):
        dss.Solution.Solve()

    def get_monitor_data(self):
        idx = dss.Monitors.First()
        pq = []
        vi = []
        while idx > 0:
            byte_stream = dss.Monitors.ByteStream()
            if '_pq' in dss.Monitors.Name():
                pq.append(byte_stream)
            else:
                vi.append(byte_stream)
            idx = dss.Monitors.Next()

        return pq, vi
