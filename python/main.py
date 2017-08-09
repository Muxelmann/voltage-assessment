import os
import numpy as np
import scipy.io as sio
from _tools import DataClass
from _tools import DSSClass

pwd = os.path.dirname(os.path.realpath(__file__))
master_path = os.path.abspath(os.path.join(pwd, './LVTestCase/Master.dss'))
data_path = os.path.abspath(os.path.join(pwd, './Daily_1min_100profiles'))
output_path = os.path.abspath(os.path.join(pwd, './output.mat'))

dss = DSSClass(master_path)
print(dss)

data = DataClass(data_path)
print(data)

voltages = None

for t in range(data.max_t):
    dss.load_power(data.power(t=t, g=np.arange(dss.load_count)))
    dss.solve_circuit()

    t_voltages = np.expand_dims(np.abs(np.mean(dss.bus_voltages(), axis=0)), 0)
    if voltages is None:
        voltages = t_voltages
    else:
        voltages = np.concatenate((voltages, t_voltages), axis=0)
    print('finished {:4d} -> {}'.format(t, voltages[-1, :]))

sio.savemat(output_path, {'voltages': voltages})
