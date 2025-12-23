# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2025-12-23

### Added
- **OpenQASM 3.0 Export** - Export quantum circuits to OpenQASM format for real quantum hardware execution
  - Full support for OpenQASM 3.0 syntax including conditionals
  - Export via `Qx.Export.OpenQASM.to_qasm/2` with customizable options
  - Supports all quantum gates, measurements, barriers, and conditional operations
  - Enables seamless integration with IBM Quantum, Rigetti, and other quantum hardware platforms
- **Error Handling Documentation (qx-gd5)** - Comprehensive CONTRIBUTING.md with error handling philosophy and best practices
  - Detailed guidelines for error types, messages, and recovery strategies
  - Error handling patterns for library developers
  - Examples of proper error propagation and context enrichment
  - Documentation of all custom error types and their use cases
- **Test Coverage Integration (qx-xbf)** - Complete test coverage metrics and CI/CD integration
  - Added ExCoveralls dependency for code coverage reporting
  - Achieved 66.4% test coverage across the codebase
  - Integrated coverage reporting into CI/CD pipeline
  - Configured multiple coverage output formats (HTML, JSON, Cobertura)
  - Added GitHub Actions integration for coverage tracking

### Changed
- **Predicate Function Conventions (qx-7iw)** - Enhanced predicate naming and specifications
  - Added `@spec` type specifications to all predicate functions
  - Improved naming conventions for boolean-returning functions
  - Enhanced documentation for predicate function usage patterns
  - Better consistency across module APIs
- **Module Documentation (qx-sdb)** - Verified comprehensive module documentation
  - Confirmed all modules have proper `@moduledoc` documentation
  - Ensured consistent documentation style across the codebase
  - Enhanced module-level descriptions and usage examples

### Fixed
- Credo strict mode compliance in OpenQASM export module
  - Refactored complex pattern matching to reduce cyclomatic complexity
  - Used `Enum.map_join/3` for better performance
  - Added inline Credo exception for legitimate gate mapping complexity

### Improved
- Development workflow with better error handling guidelines
- Code quality with comprehensive type specifications
- Test coverage visibility and tracking
- Documentation completeness and consistency
- Hardware integration capabilities via OpenQASM export

## [0.3.0] - 2025-12-21

### Added
- **Runtime Backend Selection** - Major new feature allowing backend specification at runtime without compile-time configuration
  - Added `:backend` option to `Qx.run/2`, `Qx.get_state/2`, and `Qx.get_probabilities/2`
  - Users can now specify different backends for different circuits: `Qx.run(circuit, backend: EXLA.Backend)`
  - Supports all Nx backends including EXLA (CPU/CUDA/ROCm) and EMLX (Apple Silicon GPU)
  - Combines with other options: `Qx.run(circuit, backend: EXLA.Backend, shots: 2048)`
  - Maintains full backward compatibility with existing code
  - Implemented using `Nx.with_default_backend/2` for proper scoped execution
  - Comprehensive documentation added to README.md with usage examples and best practices

### Changed
- **Draw Module Refactoring** - Reorganized visualization code for better maintainability and clarity
  - Split large 1,531-line `Qx.Draw` module into 5 focused sub-modules:
    - `Qx.Draw.VegaLite` - VegaLite chart generation for LiveBook (178 lines)
    - `Qx.Draw.SVG.Charts` - SVG histogram and bar charts (199 lines)
    - `Qx.Draw.SVG.Bloch` - Bloch sphere visualization with 3D projection (267 lines)
    - `Qx.Draw.SVG.Circuit` - Quantum circuit diagrams with IEEE notation (596 lines)
    - `Qx.Draw.Tables` - State table formatting with Kino support (196 lines)
  - `Qx.Draw` now serves as a clean API facade, delegating to specialized sub-modules
  - Maintains 100% backward compatibility - no API changes required
  - Improved code organization following single responsibility principle
  - Better separation of concerns between rendering formats and visualization types
  - All 557 tests continue to pass

### Fixed
- Fixed Nx backend configuration anti-pattern where library imposed compile-time backend choices on users
- Eliminated warnings about undefined `Nx.default_backend/2` function

## [0.2.5] - 2025-12-16
### Fixed
- More fixes to the pipeline

## [0.2.4] - 2025-12-16
### Fixed
- More automation of the release and build process
- pipeline fixes

## [0.2.3] - 2025-12-14

### Fixed
- Simplified application configuration to resolve Nx.Defn compilation issues
- Removed unnecessary application dependencies that were causing compile-time conflicts

## [0.2.2] - 2025-12-14

### Fixed
- Added `nx` and `complex` to extra_applications in mix.exs to fix compilation errors when using the Hex package
- Ensures dependencies are loaded before qx_sim compiles

### Changed
- Published to Hex.pm as `qx_sim` (package name "qx" was already taken)
- Updated installation instructions to use Hex.pm syntax
- Added Hex.pm badges to README

## [0.2.1] - 2025-11-26

### Changed
- Improved readability of Bloch sphere labels
- Refactored code and tidied up documentation
- Cleaned up old test files
- Updated README.md

### Fixed
- Fixed CNOT gate error
- Fixed dependencies
- Fixed `mix.exs` configuration

## [0.2.0] - 2025-11-01

### Added

#### Core Quantum Computing Features
- Full quantum circuit API with chainable operations via `Qx` module
- Support for 20+ quantum gates including:
  - Single-qubit gates: H, X, Y, Z, S, T, Sdg, Tdg
  - Parametric rotation gates: RX, RY, RZ with arbitrary angles
  - Two-qubit gates: CNOT (CX), CZ (Controlled-Z), SWAP
  - Multi-qubit support up to 20 qubits
- Measurement operations with classical bit storage and reset capabilities
- Conditional operations based on classical measurement results
- Statevector simulation using Nx tensors with Complex64 format
- Direct state access via `Qx.get_state/1`

#### Visualization
- Circuit diagram generation with `Qx.Draw.circuit/2` for publication-quality SVG output
- State visualization using VegaLite: bar charts, probability distributions, Bloch sphere
- SVG export capability for all visualization types
- Example visualization scripts in `examples/` directory including `circuit_visualization_example.exs`

#### Performance & Acceleration
- EXLA backend integration for CPU acceleration (~100x speedup vs Binary)
- EMLX backend support for Apple Silicon GPU acceleration (M1/M2/M3/M4)
- Automatic backend detection and configuration
- JIT compilation support via Nx.Defn

#### Benchmarking Suite
- Professional benchmarking infrastructure using Benchee
- GHZ state scaling benchmarks (5, 10, 15, 20 qubits)
- Backend comparison benchmarks (Binary, EXLA CPU, EMLX GPU, EXLA CUDA/ROCm)
- HTML report generation with interactive graphs
- Statistical analysis with warmup, iterations, and memory profiling
- Safe GPU backend detection with graceful fallback

#### Documentation & Examples
- Comprehensive API documentation with examples
- Example files demonstrating:
  - Basic quantum circuit operations
  - Complex number handling
  - Bell state creation
  - Quantum teleportation protocol
  - Conditional circuit operations
  - Grover's search algorithm
  - Circuit visualization techniques
- Performance benchmarking guide
- Backend configuration documentation

#### Error Handling
- Structured error types for better debugging:
  - `Qx.QubitIndexError` - Invalid qubit indices
  - `Qx.StateNormalizationError` - State vector normalization issues
  - `Qx.MeasurementError` - Measurement failures
  - `Qx.ConditionalError` - Conditional operation errors
  - `Qx.ClassicalBitError` - Classical bit access errors
  - `Qx.GateError` - Gate application failures
  - `Qx.QubitCountError` - Invalid qubit count specifications

### Changed
- Updated state representation to use `:c64` (Complex64) tensor format for improved performance
- Migrated from Torchx to EMLX for Apple Silicon GPU acceleration (pure Elixir, no Python)
- Enhanced error messages with context and suggestions
- Improved documentation structure with module grouping
- Updated examples to work with latest Complex number API

### Performance
- **~100x speedup** with EXLA CPU backend compared to Binary backend
- **Additional 2-10x speedup** with GPU acceleration (hardware dependent)
- Efficient statevector manipulation with direct tensor operations
- Optimized gate application avoiding unnecessary matrix construction

### Fixed
- Complex number handling in example files for `:c64` format
- CZ gate now properly exposed in main `Qx` module API
- Backend detection error handling for unavailable GPU platforms
- Output directory creation in visualization examples
- Grover's algorithm now uses proper CZ gates instead of H-CX-H decomposition

### Developer Experience
- Added `:usage_rules` dependency for better development ergonomics
- Comprehensive test suite with 549 passing tests
- Modular architecture separating concerns (Circuit, Operations, Simulation, etc.)
- Clean API design following Elixir conventions

---

## [0.1.0] - 2024-10-05

### Added
- Initial release
- Basic quantum circuit functionality
- Core gate operations
- Statevector simulation
- Nx backend integration

---

## Future Roadmap

### Potential Additions
- Additional quantum gates (Toffoli, Fredkin, controlled rotations)
- Quantum Fourier Transform implementation
- Noise models for realistic simulations
- Density matrix simulation for mixed states
- OpenQASM import/export
- Performance optimizations for larger circuits
- Integration with quantum hardware providers

---

[0.4.0]: https://github.com/richarc/qx/releases/tag/v0.4.0
[0.3.0]: https://github.com/richarc/qx/releases/tag/v0.3.0
[0.2.5]: https://github.com/richarc/qx/releases/tag/v0.2.5
[0.2.4]: https://github.com/richarc/qx/releases/tag/v0.2.4
[0.2.3]: https://github.com/richarc/qx/releases/tag/v0.2.3
[0.2.2]: https://github.com/richarc/qx/releases/tag/v0.2.2
[0.2.1]: https://github.com/richarc/qx/releases/tag/v0.2.1
[0.2.0]: https://github.com/richarc/qx/releases/tag/v0.2.0
[0.1.0]: https://github.com/richarc/qx/releases/tag/v0.1.0
