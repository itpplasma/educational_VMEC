#!/usr/bin/env python3
"""Check structure of wout file."""

import netCDF4 as nc

# Load the wout file
wout = nc.Dataset('/home/ert/code/educational_VMEC/wout_up_down_asymmetric_tokamak.nc', 'r')

# List all global attributes
print("Global attributes:")
for attr in wout.ncattrs():
    print(f"  {attr}: {getattr(wout, attr)}")

print("\nVariables:")
for var in wout.variables:
    shape = wout.variables[var].shape
    print(f"  {var}: shape={shape}")

wout.close()