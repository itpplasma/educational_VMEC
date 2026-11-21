# Unit tests for individual numerical routines.
#
# Standalone targets that compile only the sources under test, so they do not
# depend on the full vmec library or its NetCDF/FFTW/LAPACK link, except where
# a routine needs the vmec module state.

add_executable (test_spline_akima
  ${CMAKE_CURRENT_SOURCE_DIR}/test_spline_akima.f90
  ${CMAKE_SOURCE_DIR}/src/data/stel_kinds.f90
  ${CMAKE_SOURCE_DIR}/src/spline_akima.f)
set_target_properties (test_spline_akima PROPERTIES
  Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/modules)
add_test (NAME spline_akima_reflection_symmetry COMMAND test_spline_akima)

add_executable (test_becoil ${CMAKE_CURRENT_SOURCE_DIR}/test_becoil.f90)
target_link_libraries (test_becoil vmec)
set_target_properties (test_becoil PROPERTIES
  Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/modules)
add_test (NAME becoil_cubic_field COMMAND test_becoil)
