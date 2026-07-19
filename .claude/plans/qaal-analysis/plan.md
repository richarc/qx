# QAAL Lessons for Qx — Analysis & Candidate Roadmap

**Branch:** _not yet_ — this is an **analysis plan**, not an implementation
plan. It surveys the QAAL pseudo-language from the *Foundations of Quantum
Computing* (Sussex, 24/25) materials, compares it to the Qx public API,
and proposes a prioritised set of *additive* helpers that fit both the Qx
philosophy and the Elixir / Nx ecosystem. Each proposal that survives
review will spawn its **own** `feat/<slug>` branch and `plan.md`.

**Source:** User request — "review the documents in `../Reference material/`
and analyse the QAAL language … only suggest improvements to Qx if it fits
the philosophy of Qx and the Elixir / Nx ecosystem."

**Inputs analysed:**
- `Reference material/Week 4 — Many-qubit procedures: examples and
  intuitions: Prepare (Reading).pdf` — the QAAL specification (sections
  a–e: allocation, unitaries, simple subroutines, scalable subroutines,
  practical use).
- `Reference material/Foundations of Quantum Computing_Week {1..7}_Study.pdf`
  — Study materials where QAAL is exercised (teleportation, oracles,
  phase estimation, QFT, in Weeks 4–7).
- `qxportal/priv/static/tutorials/*.livemd` — current Livebook tutorials.
- `qx/lib/qx.ex`, `qx/lib/qx/operations.ex`, `qx/lib/qx/patterns.ex`,
  `qx/lib/qx/register.ex`, `qx/lib/qx/quantum_circuit.ex` — current API.

---

## 1. What QAAL is (and isn't)

QAAL — *Quantum Abstract Assembly Language* (pronounced "quall") — is a
deliberately **fictional** teaching language developed for the Sussex
module. The Week 4 Prepare reading is explicit: *"QAAL is not a real
programming language with software support."* Its purpose is **expository
precision**: a stable, low-level syntax in which to describe quantum
procedures without leaning on the inconsistencies of circuit diagrams or
the ceremony of OpenQASM / Qiskit / Cirq.

### QAAL surface (extracted from the spec)

**Allocation**
```qaal
qubit q                       # single qubit, initialised |0⟩
register R: n qubits          # n-qubit register, all |0⟩
bit b
register B: n bits
```

**Single-qubit unitaries** (each accepts a single qubit **OR** a register
— in which case the gate is applied to every qubit independently)
```qaal
X q     Y q     Z q     H q
Rx(α) q     Ry(α) q     Rz(α) q
```

**Two- and three-qubit unitaries**
```qaal
SWAP p, q
CX q, t     CY q, t     CZ q, t
CRx(α) q, t     CRy(α) q, t     CRz(α) q, t
CCX p, q, t
```

**Basis-explicit measurement** (q and r may both be single qubit/bit OR
matching-length registers)
```qaal
Mx q -> r            # X-basis measurement
My q -> r            # Y-basis measurement
Mz q -> r            # Z-basis (computational) measurement
```

**Initialise to a chosen classical value, and reset**
```qaal
MzInit q, r          # measure, then flip so the state matches r
MxInit q, r
MyInit q, r

MzReset q            # measure-then-flip to |0⟩
MxReset q            # measure-then-flip to |+⟩
MyReset q            # measure-then-flip to |+i⟩
```

**Subroutines** (procedures with typed operands and read-only parameters)
```qaal
define Mxy (alpha) q, r :
    parameter angle alpha
    operand qubit q
    operand bit r
    Rz(-alpha) q
    Mx q r
    Rz(alpha) q
    stop
```

**Scalable subroutines** (meta-parameters define register sizes; no local
qubits; recursion permitted via a separate subroutine variety)
```qaal
define ReverseQubits [n] Q :
    metaparameter integer n
    operand register Q: n qubits
    !integer j := 0
    !integer k := n - 1
    @loop:
        !jump_if_geq j, k, @endloop
        SWAP Q[j], Q[k]
        !set j := j + 1
        !set k := k - 1
        !jump @loop
    @endloop:
    stop
```

**Slicing**: `Q[1:n-2]` is a sub-register view (start..end inclusive),
used in recursive subroutines.

**Classical control**: integers and angles can be declared (`!integer
j := 3`, `!angle alpha := 2*pi/3`), mutated (`!set j := j + 1`), and
arrayed (`!array N: n integers`). Control flow is label-jump style
(`@loop:`, `!jump_if_geq`, `!jump`).

### What QAAL is for, in the module

QAAL is the **lingua franca** that Weeks 4–7 use to describe procedures
formally: quantum teleportation (4.1), phase-kickback / phase-estimation
(4.2), oracles for Deutsch–Jozsa / Bernstein–Vazirani / Grover (5),
Shor / QFT (6, 7). The reading material is explicit that QAAL is *one*
of several equivalent notations (circuit diagrams, ZX-calculus, OpenQASM)
chosen here because it scales to non-trivial classical control better
than circuit diagrams.

---

## 2. Mapping QAAL ↔ Qx (the current public API)

| QAAL | Qx (post-0.8.0, includes `Qx.Patterns`) | Verdict |
|---|---|---|
| `qubit q` / `register R: n qubits` | `Qx.create_circuit(n, m)` | ✅ direct |
| `bit b` / `register B: n bits` | `m` arg of `create_circuit/2` | ✅ direct |
| `X q`, `Y q`, `Z q`, `H q` *(single qubit)* | `Qx.x/2`, `Qx.y/2`, `Qx.z/2`, `Qx.h/2` | ✅ direct |
| `X q`, … *(applied to a whole register)* | `Qx.x_all/1`, `Qx.h_all/1`, … (Qx 0.8.0) | ✅ for *whole-circuit*; ❌ for *named sub-registers* |
| `Rx(α) q`, `Ry(α) q`, `Rz(α) q` | `Qx.rx/3`, `Qx.ry/3`, `Qx.rz/3` | ✅ direct |
| `SWAP p, q` | `Qx.swap/3` | ✅ direct |
| `CX`, `CZ`, `CCX`, `CSWAP` | `Qx.cx/3`, `Qx.cz/3`, `Qx.ccx/4`, `Qx.cswap/4` | ✅ direct |
| `CY q, t` | — | ❌ **missing** |
| `CRx(α) q, t`, `CRy(α) q, t`, `CRz(α) q, t` | only `Qx.cp/4` (controlled-phase) | ❌ **missing** |
| `Mz q -> r` *(single)* | `Qx.measure/3` | ✅ direct |
| `Mz q -> r` *(whole register)* | `Qx.measure_all/1` (Qx 0.8.0) | ✅ direct (whole circuit only) |
| `Mx q -> r`, `My q -> r` | — | ❌ **missing** (have to hand-roll H/Sdg+H prefix) |
| `MzInit q, r` *(prepare a computational-basis state from a classical bit)* | partial: `Qx.x` on |0⟩ for `r = 1`; no in-place "measure-then-flip" mid-circuit | ⚠️ **gap** |
| `MzReset q` *(reset mid-circuit)* | — | ❌ **missing** |
| `MxReset`, `MyReset` | — | ❌ **missing** |
| `define Name (params) operands: … stop` | Elixir functions on `QuantumCircuit.t()` (e.g. user-defined `apply_h_all/2` in tutorials) | ✅ Elixir functions already do this idiomatically |
| `[n]` metaparameter + `operand register Q: n qubits` | Elixir function with a `num_qubits` arg | ✅ direct |
| `Q[j]`, `Q[1:n-2]` *(slicing)* | manual: list of indices, or `Enum.slice(0..(n-1), …)` | ⚠️ **no named-register abstraction** |
| `!integer j := 0`, `!set j := j + 1`, `@loop:`, `!jump_if_geq` | `Enum.reduce/3`, recursion | ✅ Elixir/Nx idiom is functional; QAAL's imperative goto-style is **anti-idiomatic for Elixir** |
| `!array A: n angles` | plain `[float]` list / `Nx` tensor | ✅ direct |
| Recursive subroutine variety | Elixir functions / `Enum.reduce` | ✅ direct |

**Net assessment:** QAAL and Qx already converge on ~85% of the gate +
allocation surface. The genuine gaps are:

1. **Controlled rotations** (`CY`, `CRx`, `CRy`, `CRz`) — standard, widely
   used in QFT / phase estimation / Trotter circuits, decomposable
   without ambiguity. Pure additive.
2. **Basis-explicit measurement** (`Mx`, `My`) — pedagogically clear,
   trivially expressible as basis-change + Z-measure, but currently
   leaks the basis-change ceremony into every tutorial.
3. **Mid-circuit reset / init** (`MzReset`, `MzInit`) — first-class in
   OpenQASM 3 and on IBM hardware; absent from Qx.
4. **Named sub-register views** (the `register R: n qubits` /
   `R[i]` / `R[i:j]` abstraction) — the *only* genuinely new
   abstraction QAAL offers; currently users in Qx pass raw integer
   indices and re-derive sub-ranges by hand.

The imperative goto control flow and the `define / operand / parameter
/ stop` subroutine syntax are deliberately *not* in this list — they
are anti-idiomatic for Elixir and would add nothing over plain
functions, structs, and `Enum.reduce`.

---

## 3. Candidate Qx additions — fit analysis

Each candidate below is rated against three filters:

- **Qx philosophy** (pure functional pipe-friendly API, typed errors,
  per-instruction shape, no macros, no processes, additive over
  `Qx.Operations`).
- **Elixir / Nx ecosystem** (immutable, pipe-based, functions-not-
  control-flow, Nx-backend-agnostic where simulation is involved).
- **Pedagogical value** (does it make Weeks 4–7 of the Foundations
  module easier to translate into a Livebook tutorial?).

Verdicts: **A** = strong fit, propose for roadmap; **B** = medium fit,
re-evaluate after A items; **R** = poor fit, reject explicitly.

### A1 — `Qx.cy/3`, `Qx.crx/4`, `Qx.cry/4`, `Qx.crz/4` (controlled rotations + CY)
**Fit:** strong. Standard gates already in OpenQASM 3 / Qiskit / Cirq.
Pure additive over `Qx.Operations`. Each is a 2-qubit gate with a
matrix definition; the simulation backend (`Qx.Calc` / `Qx.CalcFast`) has
the contraction infrastructure for arbitrary 4×4 unitaries (see existing
`cz/3`, `cp/4`).
**Effort:** small — likely a single plan with 4 helpers + tests +
doctests + OpenQASM export entries.
**Pedagogical value:** unlocks direct transcription of QAAL `CRz(π/2)
q[0], q[1]` (Week 4) and of phase estimation circuits (Weeks 4 & 7).

### A2 — Basis-explicit measurement: `Qx.measure_x/3`, `Qx.measure_y/3`, `Qx.measure_z/3`
**Fit:** strong. Each is a 2–3-instruction macro-free wrapper:
- `measure_x(qc, q, r)` ≡ `qc |> h(q) |> measure(q, r)`
  *(post-measurement state is correct because subsequent gates on `q`
  are rare; if needed, append `h(q)` to restore.)*
- `measure_y(qc, q, r)` ≡ `qc |> sdg(q) |> h(q) |> measure(q, r)`
- `measure_z/3` is an alias of the existing `measure/3` for symmetry.
**Pedagogical value:** removes basis-change ceremony from every tutorial
that demonstrates `|+⟩/|−⟩` discrimination (currently zero tutorials do
this cleanly — it's hand-rolled if at all).
**Open question:** post-measurement state semantics. The Sussex spec is
that `Mx q -> r` *leaves q in the +/- eigenstate* matching r. Qx's
classical-then-z-measure equivalent leaves q in the *computational*
eigenstate — pedagogically different but practically identical when no
further gates run on q. **Decision needed:** match QAAL (extra basis
rotation back), or document the difference?

### A3 — `Qx.reset/2` (mid-circuit reset to |0⟩)
**Fit:** strong. OpenQASM 3 has a first-class `reset q;` instruction
and IBM hardware supports it. Qx's `:reset` instruction would be a
projection-and-relabel on the simulator side (collapse to a basis state,
record outcome internally, flip if outcome was |1⟩). Pure additive at
the API; **does** require a new `Qx.Simulation` instruction handler.
**Effort:** medium — touches `Qx.Simulation` + `Qx.SimulationResult` (no
`defn` kernel — handled at the host-side instruction dispatch layer).
Iron Law #3/#4/#5/#8 not in play; #6 (public API surface) and #7 (typed
errors) are.
**Pedagogical value:** unlocks `MzReset` translations and supports the
mid-circuit-measure-then-reuse-qubit patterns used in Week 6 (Shor) and
common in NISQ-era algorithms.

### A4 — `Qx.Register` *as a named-view abstraction over a circuit's qubits*
**Fit:** **medium-to-strong** — and the most consequential proposal here.
QAAL's `register R: n qubits` is the only abstraction QAAL offers that
genuinely is missing from Qx-the-library (as opposed to Qx-the-style).
**Note:** the existing module `Qx.Register` is a *calculation-mode*
multi-qubit primitive (state-vector evolution, immediate gate application
— see `lib/qx/register.ex:1-50`). It is **not** a circuit-mode register
view. The names collide, so any new abstraction must either:
- live under a new module (e.g. `Qx.CircuitRegister` — clunky), or
- generalise the existing `Qx.Register` to act in both modes (cleaner,
  but a public-API change to the calc-mode struct → triggers Iron Law
  #6, demands a CHANGELOG entry, possibly a major bump).

A circuit-mode register view would look like:
```elixir
{qc, alice} = Qx.QuantumCircuit.new_register(qc, "alice", 3)  # qubits 0..2
{qc, bob}   = Qx.QuantumCircuit.new_register(qc, "bob", 2)    # qubits 3..4
qc = qc
     |> Qx.h_all(alice)                     # apply H to every qubit in alice
     |> Qx.cx(alice[0], bob[0])             # alice[0] → 0, bob[0] → 3
     |> Qx.measure_all(alice)               # measure alice into classical bits 0..2
```
This lifts `h_all/1` (whole-circuit) to `h_all/2` (a register slice),
enables `R[i]` / `R[i:j]` translation directly, and lets tutorials
shadow QAAL's narrative.
**Risk:** significant API design surface — overloading, naming, scope
of slicing, interaction with classical bits, doctest update churn.
**Effort:** large — should be its own plan, gated on a design spike.
**Recommendation:** spike first (write a `Qx.QuantumCircuit.named_register/3`
API sketch and apply it to one tutorial without shipping), then decide.

### B1 — Range / list overload for `Qx.Patterns` helpers (`h_all/2`, `measure_all/2`, …)
**Fit:** medium. Cheap precursor / fallback for A4. Add a 2-arg overload:
`Qx.h_all(qc, [0, 2, 4])` or `Qx.h_all(qc, 1..3)` applies H to just
those qubits. Doesn't introduce a "register" concept; just gives users
the QAAL "operand register" semantic without the named view.
**Pedagogical value:** modest. The "explicit list of qubits" form is
clear enough that it could substitute for register-naming in tutorials.
**Effort:** small.
**Recommendation:** evaluate after A1–A3. If A4 is accepted, this folds
into A4; if A4 is deferred, ship this as a strict superset of the
existing `_all/1` helpers.

### B2 — Slicing helpers on `QuantumCircuit` (`Qx.QuantumCircuit.qubits/1`, `…/3`)
**Fit:** medium. A trivial helper that returns `Enum.to_list(0..(n-1))`
or `Enum.to_list(i..j)` — useful as the "register slice" primitive even
without first-class registers. Could be 5 lines.
**Effort:** trivial.
**Recommendation:** include in B1 if shipped; otherwise standalone.

### R1 — A QAAL DSL / transpiler (`qaal do … end` macro)
**Reject.** Reasons:
- The Sussex spec is explicit: *"QAAL is not a real programming
  language with software support."* It is **a teaching pseudo-syntax**,
  not a target.
- Qx project rule (CLAUDE.md, "Common Mistakes to Avoid"): *"Only use
  macros if explicitly requested."*
- Macros would obscure Elixir's pipe + immutable-data model — the
  thing the Elixir/Nx ecosystem is good at.
- A QAAL → Qx transpiler offers zero workflow benefit: Qx pipelines are
  *already* a clearer notation than QAAL gotos.

### R2 — Imperative classical control (`!set`, `!jump_if_geq`, `@loop:`)
**Reject.** Anti-idiomatic for Elixir. The QAAL `@loop` pattern maps
1:1 to `Enum.reduce`; recursive subroutines map 1:1 to Elixir recursion.
Both already exist in every Qx tutorial.

### R3 — A `Qx.Subroutine` struct or behaviour
**Reject.** Elixir functions on `QuantumCircuit.t()` already are
subroutines. Adding a struct around them would be ceremony with no
benefit (and would fight the pipe model).

### R4 — Mutable parameter registers (`!array N: n integers`)
**Reject.** Elixir is immutable. `Nx.tensor/2` or plain lists/maps cover
every use case in the Foundations module's QAAL programs.

---

## 4. Recommended roadmap (proposal)

The proposals above are gated **on user approval**, not auto-spawned.
Each candidate that survives review becomes its own plan slug + branch.

### Suggested order
- [ ] **A1 — controlled rotations + CY** (smallest blast radius, unlocks
      direct QAAL `CRz`/`CRx`/`CRy`/`CY` transcription). Likely ships in
      `0.8.x` or `0.9.0`.
- [ ] **A2 — basis-explicit measurement** (small surface; needs the
      post-measurement-state decision noted in §3.A2).
- [ ] **A3 — `Qx.reset/2`** (touches simulation; bigger blast radius,
      but high pedagogical + practical-hardware value).
- [ ] **A4 — design spike for named circuit-mode register views**
      (write the design as a separate plan; do not implement
      pre-emptively).
- [ ] **B1 — range/list overload for `Qx.Patterns`** (only ship if A4
      is deferred or rejected).
- [ ] **B2 — `QuantumCircuit.qubits/1,3`** (fold into A4 or B1).

### Expected ROADMAP placement
- A1 and A2 fit naturally in the **v0.8.x extension** of the existing
  unreleased `0.8.0` (still additive; same release scope as the
  `Qx.Patterns` work just merged).
- A3 may justify a **v0.9.0** anchor item because it adds a new
  instruction class to `Qx.Simulation`.
- A4 deserves its own **v0.9 or v0.10 ROADMAP heading** with the design
  spike as the first checkbox.

### Out of scope for this plan (deferred to qxportal repo)
- A "QAAL ↔ Qx" Livebook tutorial that walks Weeks 4–7 examples
  side-by-side. **Belongs in qxportal**, not in qx. Add as a single line
  under qxportal's ROADMAP once any of A1–A4 land here.

---

## 5. Verification gate (this plan)

This is an *analysis* plan; the deliverable is the document you are
reading. No code changes. Nothing to compile, format, or test in
**this** repo as a direct result of accepting this plan. Each A/B
proposal that the user approves becomes its own plan + branch + its
own verification gate (`mix compile --warnings-as-errors && mix format
--check-formatted && mix credo --strict && mix test`).

---

## 6. Open questions

These should be resolved **before** opening A1/A2/A3 plans (collected
in `scratchpad.md`):

1. **A1 — CY:** any naming concern with `cy/3`? IBM/Qiskit uses
   `cy`; QAAL uses `CY`. Recommend `Qx.cy/3` (lowercase, consistent
   with existing `cx/3`, `cz/3`).
2. **A2 — post-measurement state for `measure_x/measure_y`:** match
   QAAL (rotate back) or stay z-aligned (no rotation back)? Practical
   answer: rotate back, so post-measurement-then-further-gates is
   correct; the cost is a single extra gate, the benefit is
   "behaves like QAAL says".
3. **A3 — `reset/2`:** how does it interact with `:c_if`? Likely
   independent (reset is unconditional in QAAL).
4. **A4 — `Qx.Register` collision:** generalise the existing struct
   to dual-mode, or pick a new name (`Qx.QubitGroup`?). Decision needs
   a spike.
5. **A4 — slice syntax:** `R[i]` is `register[i]`; `R[i:j]` is a
   sub-register. In Elixir, neither bracket-access nor `:` slice
   syntax is idiomatic for a custom struct. Likely API:
   `Qx.Register.at(r, i)` / `Qx.Register.slice(r, i, j)`.

---

## 7. Risks

1. **Scope creep on A4** is the biggest risk. The named-register
   abstraction is *the* genuinely-new idea from QAAL, but it crosses
   `Qx`, `Qx.QuantumCircuit`, `Qx.Operations`, `Qx.Patterns`, and the
   existing calc-mode `Qx.Register`. A spike (not an implementation)
   is the right next step if the user is interested.
2. **Pedagogical drift**: if Qx adopts the *spelling* of QAAL but not
   the *post-state semantics* (especially for `Mx`/`My`), the tutorials
   become subtly wrong. §3.A2 / §6.2 must be resolved before shipping.
3. **API surface bloat**: every QAAL helper adds another way to do
   something. The 7 `Qx.Patterns` helpers just shipped already grew the
   surface; another 7 controlled-rotation + measurement helpers grows
   it again. The mitigation is to gate every addition on a *tutorial-
   demonstrated need*, exactly as `circuit-helpers` was.

---

## 8. What this plan **does not** do

- It does not produce any code change in qx.
- It does not modify ROADMAP.md (waiting on user approval).
- It does not spawn implementation plans (A1, A2, A3, A4 are
  proposals; each becomes its own plan iff approved).
- It does not touch qxportal (the tutorial work is the downstream
  follow-on).

---

## 9. Next step

The user reads §3 / §4 / §6 / §7 and decides which (if any) of A1–A4
+ B1–B2 to elevate to ROADMAP. For each elevated item, run
`/phx:plan <slug>` on a fresh branch.
