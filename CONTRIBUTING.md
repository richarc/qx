# Contributing to Qx

Thank you for your interest in contributing to Qx! This guide will help you understand our development practices and coding standards.

## Development Setup

1. Clone the repository
2. Install dependencies: `mix deps.get`
3. Run tests: `mix test`
4. Check code quality: `mix credo`
5. Generate documentation: `mix docs`

## Error Handling Philosophy

Qx follows a **fail-fast approach with exceptions** for all error conditions. This section documents our error-handling conventions and the rationale behind them.

### Core Principle: Raise Exceptions for All Errors

All functions in Qx raise exceptions when encountering invalid inputs or error conditions. We **do not** use tuple returns like `{:ok, result}` or `{:error, reason}`.

**Rationale:**
- Quantum computing operations have **deterministic failure modes** (invalid indices, denormalized states, etc.)
- All errors represent **programmer mistakes** that should be caught during development
- Exceptions provide **clear stack traces** for debugging
- This follows **Elixir library conventions** where tuple returns are reserved for runtime/operational failures
- Circuit construction should **fail immediately** on invalid operations rather than propagate errors

### Exception Types

We use specific exception types for different error categories:

#### 1. **Qx.QubitIndexError**
Raised when a qubit index is out of range.

```elixir
# Raises: Qx.QubitIndexError
Qx.create_circuit(2) |> Qx.h(5)
```

#### 2. **Qx.StateNormalizationError**
Raised when a quantum state is not properly normalized (∑|ψᵢ|² ≠ 1).

```elixir
# Raises: Qx.StateNormalizationError
Qx.Validation.validate_normalized!(invalid_state)
```

#### 3. **Qx.MeasurementError**
Raised when there are issues with quantum measurements:
- Attempting to get pure state from circuit with measurements
- Measuring already-measured qubits (context-dependent)

```elixir
# Raises: Qx.MeasurementError
qc = Qx.create_circuit(2, 2) |> Qx.h(0) |> Qx.measure(0, 0)
Qx.get_state(qc)  # Cannot get pure state with measurements
```

#### 4. **Qx.ConditionalError**
Raised for issues with conditional operations:
- Nested conditional operations (not supported)
- Using unmeasured classical bits in conditionals

```elixir
# Raises: Qx.ConditionalError (nested conditionals)
Qx.c_if(circuit, 0, 1, fn c ->
  Qx.c_if(c, 1, 0, fn c2 -> Qx.x(c2, 0) end)
end)
```

#### 5. **Qx.ClassicalBitError**
Raised when a classical bit index is out of range.

```elixir
# Raises: Qx.ClassicalBitError
Qx.create_circuit(2, 2) |> Qx.measure(0, 10)
```

#### 6. **Qx.GateError**
Raised for gate-related errors:
- Unsupported gate types
- Invalid gate parameters

```elixir
# Raises: Qx.GateError
Qx.Validation.validate_gate_name!(:not_a_gate)
```

#### 7. **Qx.QubitCountError**
Raised when the number of qubits is invalid (must be 1-20).

```elixir
# Raises: Qx.QubitCountError
Qx.create_circuit(25)  # Too many qubits
```

#### 8. **ArgumentError** (Standard Elixir)
Raised for general argument validation failures:
- Invalid function parameters
- Type mismatches
- Constraint violations

```elixir
# Raises: ArgumentError
Qx.QuantumCircuit.set_state(circuit, wrong_size_state)
```

### Validation Guidelines

#### When to Validate

1. **At API boundaries**: All public functions should validate inputs
2. **Before expensive operations**: Validate before running simulations
3. **State constraints**: Check normalization, dimensions, etc.

#### How to Validate

Use the centralized `Qx.Validation` module:

```elixir
# Validate qubit index
Qx.Validation.validate_qubit_index!(qubit, num_qubits)

# Validate state normalization
Qx.Validation.validate_normalized!(state)

# Validate gate name
Qx.Validation.validate_gate_name!(gate_name)
```

#### Pattern Matching with Guards

Prefer pattern matching and guards in function heads when possible:

```elixir
# Good: Use guards for simple validation
def new(num_qubits) when num_qubits > 0 and num_qubits <= 20 do
  # ...
end

# Good: Use validation functions for complex checks
def add_gate(circuit, gate, qubit) do
  Qx.Validation.validate_qubit_index!(qubit, circuit.num_qubits)
  # ...
end
```

### Documentation Requirements

All functions that can raise exceptions must document:

1. **What exceptions are raised** (in ## Raises section)
2. **Under what conditions** they are raised
3. **Example error cases** when helpful

Example:

```elixir
@doc """
Applies a Hadamard gate to the specified qubit.

## Parameters
  * `circuit` - Quantum circuit
  * `qubit` - Target qubit index

## Examples

    iex> qc = Qx.create_circuit(2) |> Qx.h(0)
    iex> length(Qx.QuantumCircuit.get_instructions(qc))
    1

## Raises

  * `Qx.QubitIndexError` - If qubit index is out of range
"""
```

### Why Not Tuple Returns?

You might wonder why we don't use `{:ok, result}` / `{:error, reason}` patterns common in Elixir. Here's why:

#### Tuple Returns Are For Runtime Errors
- File I/O that might fail due to permissions
- Network requests that might timeout
- Database queries that might not find records
- External API calls with unpredictable failures

#### Exceptions Are For Programmer Errors
- Invalid function arguments (wrong types, out of range)
- Contract violations (calling functions in wrong order)
- Invalid state (denormalized quantum states)
- Logic errors (applying gates to non-existent qubits)

All Qx errors fall into the second category - they represent bugs in the calling code, not runtime conditions.

### Future Consideration: Safe Variants

While not currently implemented, we may consider adding `safe_*` variants for key functions that return tuples:

```elixir
# Potential future API (not implemented)
Qx.h(circuit, qubit)              # Raises on error (current behavior)
Qx.safe_h(circuit, qubit)         # Returns {:ok, circuit} | {:error, reason}
```

This would only be considered if there's clear demand from users who need to handle errors programmatically without try/catch.

## Code Style

Follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide) and these project-specific conventions:

### General Guidelines

- Use `mix format` to auto-format code
- Run `mix credo` to check for style violations
- All modules must have `@moduledoc` documentation
- All public functions must have `@doc` documentation
- Use pattern matching over conditional logic when possible
- Prefer multiple function clauses over complex conditionals

### Naming Conventions

- **Predicate functions**: End with `?` (e.g., `valid_qubit?`, `has_conditionals?`)
- **Guard functions**: Use `is_` prefix (e.g., `is_binary`, `is_integer`)
- **Validation functions**: End with `!` when they raise (e.g., `validate_qubit_index!`)
- **Modules**: Use descriptive names that reflect purpose

### Documentation

- Include `## Examples` section with doctests
- Document all function parameters in `## Parameters`
- Include `## Raises` for functions that raise exceptions
- Add `## See Also` to reference related functions
- Use proper markdown formatting for code examples

Example:

```elixir
@doc """
One-line summary of the function.

Detailed description of what the function does, including
any important behavior or edge cases.

## Parameters
  * `param1` - Description of first parameter
  * `param2` - Description of second parameter

## Examples

    iex> Qx.example_function(arg1, arg2)
    expected_result

## Raises

  * `ExceptionType` - When this condition occurs

## See Also
  * `related_function/1` - Brief description
"""
```

## Testing

### Test Organization

- Tests live in `test/` directory mirroring `lib/` structure
- Use descriptive test names that explain what is being tested
- Group related tests using `describe` blocks

### Test Coverage

- Aim for high test coverage (>80%)
- Test both happy paths and error cases
- Include doctests in module documentation
- Test edge cases and boundary conditions

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/qx/validation_test.exs

# Run specific test by line number
mix test test/qx/validation_test.exs:42

# Run with coverage
mix test --cover
```

### Error Case Testing

All exception paths must be tested:

```elixir
test "raises QubitIndexError for out of range qubit" do
  circuit = Qx.create_circuit(2)

  assert_raise Qx.QubitIndexError, fn ->
    Qx.h(circuit, 5)
  end
end

test "raises ArgumentError for invalid parameter" do
  assert_raise ArgumentError, "Parameter must be a number", fn ->
    Qx.Validation.validate_parameter!("not a number")
  end
end
```

## Pull Request Process

1. **Create an issue first** for significant changes
2. **Write tests** for all new functionality
3. **Update documentation** including README if needed
4. **Run the test suite**: `mix test`
5. **Check code quality**: `mix credo`
6. **Ensure formatting**: `mix format --check-formatted`
7. **Update CHANGELOG.md** with your changes
8. **Submit PR** with clear description of changes

## Issue Tracking

This project uses **bd (beads)** for issue tracking. See AGENTS.md for details on how to work with bd.

Quick reference:
```bash
# Check for ready work
bd ready --json

# Create new issue
bd create "Issue title" -t bug|feature|task -p 0-4 --json

# Claim and update
bd update bd-42 --status in_progress --json

# Complete work
bd close bd-42 --reason "Completed" --json
```

## Questions?

- Open an issue for bugs or feature requests
- Check existing issues before creating new ones
- Join discussions on existing issues
- Read the documentation: https://hexdocs.pm/qx

## License

By contributing to Qx, you agree that your contributions will be licensed under the same license as the project (see LICENSE file).
