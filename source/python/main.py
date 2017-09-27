import os
import numpy as np
from _tools import load_data
from _tools import DSSClass

# Run basic simulation
pwd = os.path.dirname(os.path.realpath(__file__))

master_path = os.path.abspath(os.path.join(pwd, '../LVTestCase/Master.dss'))
dss = DSSClass(master_path)

dss.put_load_at_bus('318')

data_path = os.path.abspath(os.path.join(pwd, '../Daily_1min_100profiles'))
data = load_data(data_path)
data = np.concatenate((data[:, 1:dss.load_count()-2], np.zeros((np.size(data, 0), 3))), 1)
dss.set_load_shapes(data, True)

phasing = dss.get_load_phases()

dss.reset()
dss.solve()
pq, vi = dss.get_monitor_data()

total_loads = np.abs(np.array([l['P1 (kW)'].as_matrix() + l['Q1 (kvar)'].as_matrix() for l in pq])).T
total_load = np.array(np.sum(total_loads, 1), ndmin=2).T

# Generate initial random load shapes
profile_reps = 2

data_rand = [np.array([np.random.rand(total_load.size * profile_reps) for _ in range(dss.load_count())]).T]
data_scale = np.true_divide(np.tile(total_load, [profile_reps, 1]), np.array(np.sum(data_rand[-1], 1), ndmin=2).T)
data_rand[-1] = data_rand[-1] * np.tile(data_scale, [1, dss.load_count()])

# Correct each load to reduce network load error
iter_max = 10

data_rand = [data_rand[0]]

i = 0
while True:
    # Apply and simulate loadshapes
    dss.set_load_shapes(data_rand[-1])
    dss.solve()

    # Obtain data
    pq, vi = dss.get_monitor_data()
    data_rand_result = np.abs(np.array([l['P1 (kW)'].as_matrix() + l['Q1 (kvar)'].as_matrix() for l in pq])).T
    # Compute error and error statistics
    load_error = np.sum(data_rand_result, 1) - np.tile(total_load, [profile_reps, 1]).squeeze()
    mean_error = np.mean(load_error)
    std_error = np.std(load_error)

    print('# {} -> mean: {:3.9f}; std: {:3.9f}'.format(i+1, mean_error, std_error))

    # Subtract error
    load_delta = np.multiply(data_rand[-1], np.tile(load_error, [dss.load_count(), 1]).T)
    load_delta = np.divide(load_delta, np.tile(np.sum(data_rand[-1], 1), [dss.load_count(), 1]).T)
    data_rand.append(data_rand[-1] - load_delta)

    i += 1
    if iter_max < i or (np.round(mean_error + std_error, 4) == 0 and np.round(mean_error - std_error, 4) == 0):
        break
