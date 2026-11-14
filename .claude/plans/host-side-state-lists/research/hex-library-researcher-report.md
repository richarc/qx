# Research: Nx primitives for basis_state/3 and build_probability_tensor/2

Tags: [M]=measured, [S]=read from source, [I]=inferred. Scripts: scratchpad/{cur,bench,types,sem,prob}.exs (harness.exs) under
/private/tmp/claude-501/-Users-richarc-Development-qxquantum-qx/0691e064-69c8-4e10-869e-7164d1ec6da6/scratchpad/

## A. Dependencies
No new dependency. `{:nx, "~> 0.12"}` mix.exs:55, locked nx 0.13.0 (+ complex 0.7.0) mix.lock:34,7 [S]. EXLA/EMLX are NOT deps (mix.exs:56-58 comment) [S]. Elixir 1.20.2 / OTP 29 locally; mix.exs:8 requires ~> 1.18.

## B. Candidates on Nx.BinaryBackend (deps/nx/lib/nx/binary_backend.ex unless noted)
- indexed_put/indexed_add: nx.ex:8354 / 8165; backend 1713-1726, shared indexed_op 1728-1812 [S]. Works on c64/c128 and real types [M]. No loop over target size: only per-update-pair lists/group_by/sort (1735-1760), then binary slicing of target (1787-1800) with a per-element `for` only over one `target_chunk` (a single element for rank-1) (1795-1797) [S]. Duplicate indices: put = last wins (resolve_updates `Enum.at(upds,-1)`, 1722) [S,M]; add = sums [M]. Indices out of bounds (>= size or negative) RAISE ArgumentError "index 5 is out of bounds for axis 0 in shape {4}" (index_to_binary_offset 1976-1982) [S,M]. Empty index/updates raise RuntimeError "cannot build empty tensor" [M]. Result type follows updates: f32 target + f64 updates gives f64 [M] (cast updates to :f32 explicitly). Input order irrelevant (sorted by offset, 1757) [M].
- put_slice: nx.ex:14379, backend 1895-1925. Loop is over slice elements (1 here), but each iteration rebuilds `<<before, new, rest>>` (copies the tensor once) [S]. Works c64/c128/f32/s32 [M]. Rank-1 clamps start index (clamp_indices 1897) so an out-of-range index is silently clamped, not raised [S, inferred not run].
- equal(iota)|>as_type: iota rank-1 is a HOST per-element loop `for i <- 0..(n-1), do: number_to_binary(i, type)` (binary_backend.ex:58-61) [S]; as_type is also a per-element `for <<x <- data>>` comprehension (2062-2085) [S]; element_wise equal likewise [I]. Measured ~25x slower than alternatives at 2^22 [M].
- pad of 1-element tensor: backend pad 326-345, pad_last_dim 347+: builds edge padding with `for(_ <- 1..edge_high, into: <<>>, do: value)` (host loop per padded element) and a per-element comprehension over the data [S]. Works c64/c128/f32/s32 [M]. ~8x slower than put_slice at 2^22 [M].
- concatenate zeros/one/zeros: nx.ex:15231, backend 2005-2017, axis 0 uses `:erlang.list_to_bitstring` (2020-2022) [S]. No per-element loop, but zero-length parts RAISE (ArgumentError "invalid dimension in axis 0 ... must be a positive integer") so index 0 / dim-1 need branches [M]. Zeros come from Nx.broadcast.
- Nx.broadcast of scalar: backend 224-236, scalar case `:binary.copy(bin, size)` (232-236), no loop [S].
- Nx.from_binary: nx.ex:2004-2017: validates size and non-empty, then backend.from_binary (binary_backend.ex:115) [S]. Zero loops. Works for any type IF the caller writes the right element bytes (complex = two floats; a c64 one written into :s32 silently gives garbage 1065353216 [M]); the type check `Nx.Type.normalize!` happens first so :bogus raises the same ArgumentError [M].

Real/int/bogus type with candidates [M]: all Nx-op candidates (indexed_put, put_slice, equal|>as_type, pad, concatenate) return a valid real tensor for :f32 ([0.0,1.0,0.0,0.0] f32) and :s32 ([0,1,0,0] s32); :bogus raises ArgumentError "invalid numerical type: :bogus (see Nx.Type docs for all supported types)".

## C. Current behaviour (run) [M]
| call | result |
|---|---|
| basis_state(1,4) | {:c,64} shape {4} [0,1,0,0] |
| (1,4,:c128) | {:c,128} {4} |
| (1,4,{:c,64}) | {:c,64} {4} (short/long forms equal) |
| (1,4,:f32) | CaseClauseError "no case clause matching: 0.0+0.0i" |
| (1,4,:s32) | ArgumentError "construction of binary failed: segment 1 of type 'integer': expected an integer but got: 0.0+0.0i" |
| (1,4,:bogus) | ArgumentError "invalid numerical type: :bogus (see Nx.Type docs for all supported types)" |
| (0,1) | {:c,64} {1} [1.0+0.0i] |
build_probability_tensor output: {:f,32} shape {2^n}; empty pairs: zeros {:f,32}; duplicate index: last write wins (0.25,0.5 -> 0.5); index >= size dropped silently [M]. (It is private; I replicated its body in cur.exs/prob.exs.)

## D. Measurements [M]
Method: one cold run per point in a freshly spawned process; wall = System.monotonic_time around the call (ms); peak = max over 1 ms polling of `:erlang.memory(:total)` minus baseline taken after a GC. Polling at 1 ms misses short spikes, so small peaks (<= few MB) are lower bounds (e.g. indexed_put 0.2 MB at 2^20 cannot be right for a 8 MB result; treat as unobserved). Wall times of 0-1 ms are at the clock resolution. No point exceeded 60 s.

### basis_state, c64 (c128 is similar, ~2x memory; wall equal within noise)
| dim | current | indexed_put | indexed_add | put_slice | equal(iota) | pad | concatenate | from_binary |
|---|---|---|---|---|---|---|---|---|
| 2^10 | 10 ms / 1.8 MB | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| 2^16 | 11 ms / 18 MB | 0 | 0 | 0 | 7 ms | 1 | 0 | 0 |
| 2^20 | 221 ms / 296 MB | 4 ms | 4 ms | 4 ms | 135 ms / 104 MB | 28 ms / 32 MB | 4 ms / 16 MB | 4 ms |
| 2^22 | 1079 ms / 1347 MB | 17 ms / 64 MB | 16 ms / 64 MB | 17 ms / 71 MB | 472 ms / 310 MB | 138 ms / 134 MB | 16 ms / 32 MB | 16 ms / 32 MB |
c128 at 2^22: current 928 ms / 1347 MB; indexed_put 19 ms / 128 MB; put_slice 19 ms / 141 MB; concatenate 18 ms / 128 MB; from_binary 18 ms / 64 MB; equal(iota) 483 ms / 310 MB; pad 148 ms / 236 MB.

### build_probability_tensor (1000 pairs spread evenly; all indices when 2^n < 1000... at 2^10 n=1000 of 1024)
| size | current | indexed_put | indexed_add | from_binary (sorted iodata) |
|---|---|---|---|---|
| 2^10 | 14 ms / 2 MB | 3 ms | 1 ms | 0 ms |
| 2^16 | 278 ms / 15 MB | 1 ms | 1 ms | 0 ms |
| 2^20 | 4503 ms / 151 MB | 5 ms / 4 MB | 5 ms / 4 MB | 1 ms |
| 2^22 | 17654 ms / 800 MB | 17 ms / 16 MB | 17 ms / 16 MB | 3 ms / 32 MB |
(indexed_* include zero broadcast, index/update tensor building from lists, and the OOB filter.) Current scales ~O(pairs x 2^n), confirming the issue.

Equivalence check [M]: current, filtered indexed_put and from_binary-sorted all give [0.0,0.25,0.0,0.5] for [{3,.5},{1,.25},{9,1.0}] at 2 bits.

## E. Recommendation
1. basis_state: `Nx.indexed_put(Nx.broadcast(Nx.tensor(0, type: type), {dim}), Nx.tensor([[index]]), Nx.tensor([1], type: type))`.
   Or put_slice (`Nx.put_slice(zeros, [index], Nx.tensor([1], type: type))`) which is a one-line and equally fast; both ~60x faster and ~20x less memory than current at 2^22. Pick indexed_put: no zero-length edge cases (unlike concatenate), no clamping surprise, and it raises on an out-of-range index (guard clause already ensures in-range). Avoid equal(iota), pad (host loops, 8-25x slower) and hand-built from_binary (fastest, but encodes the c64/c128 layout by hand and silently yields garbage for non-complex types) [I].
   Behaviour differences: (a) a real type (:f32/:s32) now SUCCEEDS returning one-hot f32/s32 instead of raising CaseClauseError/ArgumentError; add an explicit complex-type guard (`Nx.Type.normalize!(type)` then `Nx.Type.complex?/1`) if raising is to be preserved, and decide the exception module (today it is incidental); (b) :bogus keeps the same ArgumentError "invalid numerical type: :bogus ..." (raised in Nx.tensor(0, type: :bogus)) [M]; (c) {:c,64} and :c64 both still work; dtype/shape identical [M]; (d) dimension 1 works [M].
2. build_probability_tensor: `Nx.indexed_put` onto an f32 zero broadcast, after (i) `Map`/`Enum.filter` dropping `index >= size`, (ii) casting updates with `type: :f32` (otherwise f64 updates promote the result to f64), (iii) a branch for empty pairs (indexed_put raises "cannot build empty tensor"; return the zeros tensor). Use `Nx.tensor(list_of_[i], type: :s64)` for indices.
   Duplicate-index semantics: indexed_put = last write wins in input order, identical to List.replace_at today; indexed_add would SUM duplicates (different result, 0.25+0.5=0.75) so do not use it unless additive is wanted. The "1" vs "01" same-index case is therefore preserved with indexed_put. Output dtype stays {:f,32}; empty pairs stays f32 zeros (with the branch); OOB dropping preserved only through the explicit filter (Nx would raise otherwise) [M].
   Alternative if the pair count ever grows large: from_binary with sorted iodata was 5x faster at 2^22 but needs a manual Map.new dedupe (last wins) and f32 byte layout; not needed at 1000 pairs.
