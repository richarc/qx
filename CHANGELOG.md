# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Phase 2: Gate Application Consolidation**
  - Refactored `Qx.Simulation` to delegate all gate operations to `Qx.Calc` module
  - Removed 111 lines of duplicate gate application code
  - Fixed qubit ordering in measurement functions to use standard convention (qubit 0 = leftmost/MSB)
  - Improved consistency between Circuit mode and Register mode

### Added
- **Phase 3: Test Coverage Improvement**
  - Added comprehensive test suite for `Qx.Math` module (37 tests)
  - Added comprehensive test suite for `Qx.Gates` module (17 tests)
  - Added comprehensive test suite for `Qx.Calc` module (23 tests)
  - Total test count increased from 276 to 539 tests (186 doctests + 353 unit tests)

### Fixed
- Fixed all doctest formatting issues in `Qx.Math` module (8 failures resolved)
- Fixed `Math.is_unitary?/1` function bug with complex tensor arithmetic
  - Changed from `-` operator to `Nx.subtract/2` for proper tensor subtraction
  - Relaxed tolerance from 1.0e-10 to 1.0e-6 for floating-point comparisons
- Removed unused default parameters in test helper functions (eliminated compiler warnings)

### Improved
- **Test Coverage**: Increased from 59.52% to 62.46%
  - `Qx.Calc`: 100% coverage ✅
  - `Qx.Math`: 97.73% coverage ✅
  - `Qx.Simulation`: 90.10% coverage ✅
  - `Qx.Register`: 98.80% coverage ✅
- Clean test output with zero compiler warnings
- All 539 tests passing with 0 failures and 0 skipped tests

## [0.1.1] - 2025-01-02

### Added
- ExDoc documentation generation support
- Comprehensive API documentation for all public functions
- Type specifications (@spec) for all public functions in main Qx module
- CHANGELOG.md for tracking version history
- Hex package metadata configuration
- Module organization into logical groups for documentation

### Documentation
- Enhanced module documentation with usage examples
- Added doctest examples to all public functions
- Organized modules into groups: Core API, Circuit Building, Simulation, Visualization, and Mathematical Functions

## [0.1.0] - Initial Release

### Added
- Quantum circuit creation and manipulation
- Support for up to 20 qubits with statevector simulation
- Single-qubit gates: H, X, Y, Z, S, T, RX, RY, RZ, Phase
- Multi-qubit gates: CNOT, Toffoli (CCX), CZ
- Measurement operations with classical bit storage
- Circuit simulation with configurable shot counts
- Probability distribution calculation
- VegaLite-based visualization for results
- SVG circuit diagram generation
- Complex number support via Nx c64 tensors
- Convenience functions for common quantum states (Bell, GHZ, superposition)
- Mathematical utilities for quantum computing (Kronecker product, normalization, etc.)
