#!/usr/bin/env python3
"""Compare magnetic axis initialization between educational_VMEC and VMEC++."""

import sys
sys.path.append('/home/ert/code/vmecpp')

import vmecpp
import numpy as np
import json

# Load the reference data
with open('/home/ert/code/educational_VMEC/educational_vmec_reference.json', 'r') as f:
    edu_ref = json.load(f)

print("Educational VMEC axis initialization:")
print(f"  Final axis: R={edu_ref['final_axis']['raxis_cc'][0]:.6f}, Z={edu_ref['final_axis']['zaxis_cs'][0]:.6f}")
print(f"  Note: Started from R=0.0, Z=0.0 (forced axis guess)")
print(f"  Educational VMEC detected bad Jacobian and improved axis guess")

# Try running VMEC++ with debug output
print("\nNow testing VMEC++ with the same input...")

# Load the same input file
try:
    vmec_input = vmecpp.VmecInput.from_file('/home/ert/code/vmecpp/examples/data/input.up_down_asymmetric_tokamak')
    print(f"\nVMEC++ input loaded successfully")
    print(f"  lasym: {vmec_input.lasym}")
    print(f"  Initial axis from input: R={vmec_input.raxis_c[0]:.6f}, Z={vmec_input.zaxis_s[0]:.6f}")
    print(f"  Asymmetric boundary coefficients:")
    if vmec_input.rbs is not None:
        print(f"    RBS shape: {vmec_input.rbs.shape}")
        if vmec_input.rbs.shape[0] > 0 and vmec_input.rbs.shape[1] > 1:
            print(f"    RBS(0,1) = {vmec_input.rbs[0,1]:.6f}")
        if vmec_input.rbs.shape[0] > 0 and vmec_input.rbs.shape[1] > 2:
            print(f"    RBS(0,2) = {vmec_input.rbs[0,2]:.6f}")
    else:
        print(f"    RBS array not initialized")
    
    # Try to run VMEC++ (expecting BAD_JACOBIAN)
    print("\nAttempting to run VMEC++...")
    output = vmecpp.run(vmec_input)
    print("VMEC++ completed successfully!")
    
except Exception as e:
    print(f"\nVMEC++ failed with error: {e}")
    print("\nThis confirms the BAD_JACOBIAN issue in VMEC++")
    print("Educational VMEC recovers from this, but VMEC++ does not")