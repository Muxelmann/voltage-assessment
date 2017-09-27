import os
import numpy as np
from _tools import load_data
from _tools import DSSClass

# Run basic simulation
pwd = os.path.dirname(os.path.realpath(__file__))

master_path = os.path.abspath(os.path.join(pwd, '../LVTestCase/Master.dss'))
dss = DSSClass(master_path)

dss.put_load_at_bus('318')

load_meters = dss.get_load_meter_and_phase()
print(len(load_meters))
for key in load_meters.keys():
	print('{} -> {}'.format(key, load_meters[key]))
