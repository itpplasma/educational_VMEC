# CRITICAL BUG FOUND: VMEC++ Asymmetric Mode Boundary Evaluation

## Summary
VMEC++ fails on asymmetric cases because it incorrectly handles the theta range in `guess_magnetic_axis.cc`, leaving half the boundary values as zeros.

## Root Cause
In `RecomputeMagneticAxisToFixJacobianSign()`:

1. **Arrays are allocated for full theta range**: `w.r_lcfs[k].resize(s.nThetaEven)` where `nThetaEven=16`

2. **Only first half is computed**: The loop from line 232-335 only fills indices 0 to `nThetaReduced-1` (approximately half)

3. **Mirroring only happens for symmetric cases**: Lines 339-357 apply flip-mirror ONLY when `!s.lasym`

4. **Result**: For asymmetric cases, theta indices 9-15 remain at default value 0.0

## Evidence
```
DEBUG: LCFS boundary values at k=0:
  theta[0]: R=6.90098 Z=0.268328   # Correct values
  theta[1]: R=6.96519 Z=0.453272
  ...
  theta[9]: R=0 Z=0                 # All zeros!
  theta[10]: R=0 Z=0
  ...
  theta[15]: R=0 Z=0
  WARNING: Found R=0 at theta index 9-15
```

## Consequence
- `rmin = 0` instead of correct ~5.27
- Axis guess: R=3.48 instead of correct ~6.1
- Grid search includes singular R=0 region
- BAD_JACOBIAN error and convergence failure

## Fix Required
For asymmetric mode, either:
1. Only use theta range 0 to `nThetaReduced` (like educational_VMEC)
2. Or properly compute the full theta range without mirroring

## Comparison with educational_VMEC
Educational_VMEC works because:
- It only uses indices 1 to `ntheta3` for asymmetric cases
- Never accesses the uninitialized second half
- Correctly computes `rmin=5.272`, avoiding R=0