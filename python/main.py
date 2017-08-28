import os
import numpy as np
from _tools import load_data
from _tools import DSSClass

# Run basic simulation
pwd = os.path.dirname(os.path.realpath(__file__))
master_path = os.path.abspath(os.path.join(pwd, './LVTestCase/Master.dss'))
data_path = os.path.abspath(os.path.join(pwd, './Daily_1min_100profiles'))
data = load_data(data_path)

dss = DSSClass(master_path)
dss.set_load_shapes(data, True)
print(dss)

dss.solve()
pq, vi = dss.get_monitor_data()

total_load = np.sum(np.array([l['S1 (kVA)'].as_matrix() for l in pq]), 0)

