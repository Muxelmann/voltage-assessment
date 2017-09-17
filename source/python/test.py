import _tools.opendssdirect as dss
import pandas as pd

# Read file
dss.run_command('compile /Users/maxi/Desktop/voltage-assessment/OpenDSSDirect.py/tests/data/13Bus/IEEE13Nodeckt.dss')
# Add monitor
# dss.run_command('new Monitor.transformer_vi element=Transformer.Sub Terminal=1 Mode=0')
# dss.run_command('new Monitor.transformer_pq element=Transformer.Sub Terminal=1 Mode=1')
# dss.run_command('new Monitor.line_1_vi element=Line.650632 Terminal=1 Mode=0')
# dss.run_command('new Monitor.line_1_pq element=Line.650632 Terminal=1 Mode=1')
dss.run_command('new Monitor.load_vi Element=Load.671 Terminal=1 Mode=0')
dss.run_command('new Monitor.load_pq Element=Load.671 Terminal=1 Mode=1')
# Solve

idx = dss.Loads.First()
while idx > 0:
    dss.Loads.Daily('default')
    idx = dss.Loads.Next()

dss.Solution.Mode(1)
dss.Solution.Solve()

# Read ByteStream
assert dss.Monitors.Count() > 0
idx = dss.Monitors.First()
while idx > 0:
    data = dss.Monitors.ByteStream()
    print(dss.Monitors.Name())
    print(data.head())
    print('')
    idx = dss.Monitors.Next()
# Returns `pd.DataFrame` with misaligned data