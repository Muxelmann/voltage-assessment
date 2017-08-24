import os
import pandas as pd
import numpy as np


class DataClass:

    _raw = None

    _iter_i = 0
    _iter_paths = []
    _iter_order = []

    def __init__(self, path=None):
        if path is None:
            return

        dir_content = os.listdir(path)
        self._iter_paths = []
        for f_name in dir_content:
            self._iter_paths.append(os.path.join(path, f_name))
            profile = pd.read_csv(self._iter_paths[-1], header=None)
            if self._raw is None:
                self._raw = profile.values
            else:
                self._raw = np.append(arr=self._raw, values=profile.values, axis=1)
        self.set_random_iteration(True)
        print(self._iter_order)

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

    def set_random_iteration(self, is_random):
        if is_random:
            self._iter_order = np.random.permutation(len(self._iter_paths))
        else:
            self._iter_order = np.arange(len(self._iter_paths))

    def __iter__(self):
        self._iter_i = 0
        return self

    def __next__(self):
        self._iter_i += 1
        if len(self._iter_paths) < self._iter_i:
            raise StopIteration
        else:
            return self._iter_paths[self._iter_order[self._iter_i-1]]

    def csvs(self, n=None):
        if n is not None and 0 < n <= len(self._iter_paths):
            return [self._iter_paths[self._iter_order[i]] for i in range(n)]
        else:
            return [csv for csv in self]

    @property
    def max_t(self):
        return np.size(self._raw, axis=0)

    @property
    def max_g(self):
        return np.size(self._raw, axis=1)
