#!/usr/bin/env python3
"""Extract reference data from educational_VMEC output for asymmetric test case."""

import netCDF4 as nc
import numpy as np
import json

# Load the wout file
wout = nc.Dataset('/home/ert/code/educational_VMEC/wout_up_down_asymmetric_tokamak.nc', 'r')

# Extract key data
reference_data = {
    'final_axis': {
        'raxis_cc': wout.variables['raxis_cc'][:].tolist(),
        'zaxis_cs': wout.variables['zaxis_cs'][:].tolist(),
        'raxis_cs': wout.variables['raxis_cs'][:].tolist() if 'raxis_cs' in wout.variables else None,
        'zaxis_cc': wout.variables['zaxis_cc'][:].tolist() if 'zaxis_cc' in wout.variables else None
    },
    'convergence': {
        'fsqr': float(wout.variables['fsqr'][()]),
        'fsqz': float(wout.variables['fsqz'][()]),
        'fsql': float(wout.variables['fsql'][()])
    },
    'equilibrium': {
        'aspect': float(wout.variables['aspect'][()]),
        'volume': float(wout.variables['volume_p'][()]),
        'wmhd': float(wout.variables['wb'][()]),
        'betatotal': float(wout.variables['betatotal'][()]),
        'betapol': float(wout.variables['betapol'][()]),
        'betator': float(wout.variables['betator'][()]),
        'iotaf': wout.variables['iotaf'][:].tolist()
    },
    'fourier_modes': {
        'mnmax': int(wout.variables['mnmax'][()]),
        'xm': wout.variables['xm'][:].tolist(),
        'xn': wout.variables['xn'][:].tolist()
    },
    'asymmetric_coefficients': {
        'rmnc': wout.variables['rmnc'][:].tolist(),
        'zmns': wout.variables['zmns'][:].tolist(),
        'rmns': wout.variables['rmns'][:].tolist() if 'rmns' in wout.variables else None,
        'zmnc': wout.variables['zmnc'][:].tolist() if 'zmnc' in wout.variables else None,
        'lmns': wout.variables['lmns'][:].tolist() if 'lmns' in wout.variables else None
    }
}

# Save to JSON for easy comparison
with open('/home/ert/code/educational_VMEC/educational_vmec_reference.json', 'w') as f:
    json.dump(reference_data, f, indent=2)

# Print summary
print("Educational VMEC Reference Data Extracted:")
print(f"Final axis at s=0: R={reference_data['final_axis']['raxis_cc'][0]:.6f}, Z={reference_data['final_axis']['zaxis_cs'][0]:.6f}")
print(f"Convergence: fsqr={reference_data['convergence']['fsqr']:.2e}, fsqz={reference_data['convergence']['fsqz']:.2e}")
print(f"Equilibrium: aspect={reference_data['equilibrium']['aspect']:.3f}, volume={reference_data['equilibrium']['volume']:.3f}")
print(f"Number of Fourier modes: {reference_data['fourier_modes']['mnmax']}")

# Check for asymmetric components
if reference_data['asymmetric_coefficients']['rmns'] is not None:
    print("Asymmetric R coefficients (rmns) found")
if reference_data['asymmetric_coefficients']['zmnc'] is not None:
    print("Asymmetric Z coefficients (zmnc) found")

wout.close()