# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
