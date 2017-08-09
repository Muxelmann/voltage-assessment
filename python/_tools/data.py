import os
import pandas as pd
import numpy as np


class DataClass:

    _raw = None

    def __init__(self, path=None):
        if path is None:
            return

        dir_content = os.listdir(path)

        for f_name in dir_content:
            profile = pd.read_csv(os.path.join(path, f_name), header=None)
            if self._raw is None:
                self._raw = profile.values
            else:
                self._raw = np.append(arr=self._raw, values=profile.values, axis=1)

    def __repr__(self):
        if self._raw is None:
            return "No data available"
        else:
            return "DataClass({}, {})".format(np.size(self._raw, axis=0), np.size(self._raw, axis=1))

    def power(self, t, g=np.array([])):
        if np.size(g) == 0:
            g = np.arange(np.size(self._raw, axis=1))
        if np.max(g) >= np.size(self._raw, axis=1) or np.min(g) < 0:
            return None
        if t >= np.size(self._raw, axis=0) or t < 0:
            return None
        return self._raw[t, g]

    @property
    def max_t(self):
        return np.size(self._raw, axis=0)

    @property
    def max_g(self):
        return np.size(self._raw, axis=1)
