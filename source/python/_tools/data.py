import os
import pandas as pd
import numpy as np


def load_data(path=None):
    if path is None:
        return np.array([])

    dir_content = os.listdir(path)
    raw_data = None

    for f_name in dir_content:
        data_path = os.path.join(path, f_name)
        profile = pd.read_csv(data_path, header=None)
        if raw_data is None:
            raw_data = profile.values
        else:
            raw_data = np.append(arr=raw_data, values=profile.values, axis=1)

    return np.round(raw_data, 4)
