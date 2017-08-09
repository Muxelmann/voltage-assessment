import _tools.opendssdirect as dss


class DSSClass:

    _startup = False
    _load_count_original = 0

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

    def solve_circuit(self, quick=False):
        NotImplemented()

    def load_power(self, p, q=None):
        NotImplemented()
