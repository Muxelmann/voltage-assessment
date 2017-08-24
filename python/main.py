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

# dir_content = os.listdir(path)
#         self._iter_paths = []
#         for f_name in dir_content:
#             self._iter_paths.append(os.path.join(path, f_name))

# print([os.path.join(data_path, f_name) for f_name in os.listdir(data_path)])

# data = DataClass(data_path)
# print(data)

dss.load_shapes = [os.path.join(data_path, f_name) for f_name in os.listdir(data_path)]
print(dss.load_shapes)
voltages = None

dss.solve_circuit()

# for t in range(data.max_t):
#     dss.load_power(data.power(t=t, g=np.arange(dss.load_count)))
#     dss.solve_circuit()
#
#     t_voltages = np.expand_dims(np.abs(np.mean(dss.bus_voltages(), axis=0)), 0)
#     if voltages is None:
#         voltages = t_voltages
#     else:
#         voltages = np.concatenate((voltages, t_voltages), axis=0)
#     print('finished {:4d} -> {}'.format(t, voltages[-1, :]))
#
# sio.savemat(output_path, {'voltages': voltages})
