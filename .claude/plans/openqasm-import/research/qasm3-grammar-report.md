# OpenQASM 3.0 — Subset We Will Parse

## Header (mandatory)
- `OPENQASM 3.0;` — required first non-comment statement
- `include "stdgates.inc";` — optional, treat as **no-op** (just whitelists stdgate names)

## Lexical
- Comments: `//` to EOL and `/* ... */` (block, may nest)
- Identifiers: `[A-Za-z_][A-Za-z0-9_]*`, no leading `__`
- Numbers: decimal, decimal-with-underscores, scientific (`1e-3`), hex/oct/bin (likely unused in QASM source)
- Constant: `pi` (and `π`) — predefined float

## Declarations (accept both modern and legacy)
| Modern (QASM 3) | Legacy (QASM 2) | Notes |
|---|---|---|
| `qubit[N] q;` | `qreg q[N];` | quantum register |
| `bit[N] c;` | `creg c[N];` | classical register |

**Multiple registers**: legal in QASM 3, but Qx's `QuantumCircuit` models a single quantum + single classical register. **v1 supports single-register programs only**; reject multi-register input with a clear error pointing at the second declaration's line.

## Gate calls
- `h q[0];`
- `cx q[0], q[1];`
- `rx(theta_expr) q[0];`
- `u(t, p, l) q[0];`
- Parameter expressions: numeric literals, `pi`, `+ - * /`, unary minus, parentheses, function calls (`sin`, `cos`, `tan`, `exp`, `ln`, `sqrt`). Evaluated at parse time → float.

## Measurement (accept both)
- `c[i] = measure q[j];` (modern, preferred)
- `measure q[j] -> c[i];` (legacy)
- `measure q[j];` (discarded result) — accept and emit warning OR reject. **Decision: reject for v1** (Qx requires a classical bit target).

## Conditionals
- `if (c[i] == N) { stmt; stmt; }` — supported, maps to `:c_if`
- `if (c[i] == N) stmt;` (no braces) — supported, single-instruction body
- **`else` branch** — Qx's `:c_if` has no else; reject with a clear error explaining how to refactor into two ifs (the second guarded by `if (c[i] != N)` once we support `!=`)
- Complex conditions (`&&`, `||`, register-wide `c == N`) — out of scope for v1; reject

## Barrier
- `barrier q[i], q[j], ...;` — explicit qubit list
- `barrier q;` — whole register → expand to all qubits
- `barrier;` — out of scope; reject

## Gate definitions (powers `from_qasm_function/1`)
- Form: `gate name(p1, p2) a, b, c { body }`
- Body restrictions per spec: only built-in gates, previously-defined gates, and modifiers (`inv`, `pow`, `ctrl`, `negctrl`)
- **v1 scope**: body may use only stdgates calls (no nested user-defined gate references; no modifiers). Reject `inv @`, `pow(...)@`, `ctrl @`, `negctrl @` for v1 with explicit "modifier not yet supported" error.

## stdgate vocabulary mapping → Qx instruction tuples

| QASM | Qx instruction | Notes |
|---|---|---|
| `h` | `{:h, [q], []}` | direct |
| `x`, `y`, `z` | `{:x/:y/:z, [q], []}` | direct |
| `s`, `sdg`, `t` | `{:s/:sdg/:t, [q], []}` | direct |
| `tdg` | — | **decompose**: `tdg = phase(-pi/4)` |
| `sx` | — | **decompose**: `sx = u(pi/2, -pi/2, pi/2)` |
| `id` | — | **no-op**: drop instruction (or emit `barrier [q]` to preserve timing? **decision: drop**) |
| `p(λ)` | `{:phase, [q], [λ]}` | direct alias |
| `phase(λ)` | `{:phase, [q], [λ]}` | direct |
| `rx`, `ry`, `rz` | `{:rx/:ry/:rz, [q], [θ]}` | direct |
| `u(θ,φ,λ)`, `u3(θ,φ,λ)` | `{:u, [q], [θ,φ,λ]}` | direct |
| `u1(λ)` | `{:phase, [q], [λ]}` | u1 ≡ phase per spec |
| `u2(φ,λ)` | `{:u, [q], [pi/2, φ, λ]}` | u2 = u(pi/2, φ, λ) |
| `cx`, `CX` | `{:cx, [c,t], []}` | direct (CX is uppercase alias) |
| `cz` | `{:cz, [c,t], []}` | direct |
| `swap` | `{:swap, [a,b], []}` | direct |
| `cp(λ)`, `cphase(λ)` | `{:cp, [c,t], [λ]}` | direct |
| `ccx` | `{:ccx, [c1,c2,t], []}` | direct |
| `cswap` | `{:cswap, [c,a,b], []}` | direct |
| `cy`, `ch`, `crx`, `cry`, `crz`, `cu` | — | **unsupported** in v1 (Qx has no equivalent); raise `Qx.QasmUnsupportedError` with the gate name and `:not_implemented_in_qx` reason |
| `iswap` | `{:iswap, [a,b], []}` | direct (Qx has it; not in stdgates.inc but commonly used) |
| `rxx`, `ryy`, `rzz`, `rzx` | — | **not in stdgates.inc**; reject with hint that they're Qiskit extensions |

## Explicitly excluded (clear error citing spec)
| Feature | Spec area |
|---|---|
| `def` (subroutines) | classical functions |
| `for`, `while`, `switch`/`case`, `break`, `continue` | classical control flow |
| `int`, `uint`, `float`, `bool`, `complex`, `angle`, `array`, `duration`, `stretch` | classical types beyond `bit` |
| `defcal`, OpenPulse | pulse-level |
| `let` | aliases |
| `pragma` | implementation-specific |
| `extern` | external subroutines |
| `box`, `delay` | timing |
| `reset` | qubit reset |
| Gate modifiers (`inv`, `pow`, `ctrl`, `negctrl`) | gate algebra |
| Annotations (`@name`) | metadata |
| Multi-register programs | Qx's data model |

Each rejection raises `Qx.QasmUnsupportedError` with `{:feature, name, line, col}` so the portal can surface a structured error.
