# Scratchpad: draw-rework

## Discovered: stale calc-mode livebooks inside qx

`examples/tutorials/*.livemd` and `test/qx_manual_test.livemd` still
alias `Qx.Qubit` (hidden since v0.10) — pre-rewrite copies of content
qxportal now owns. Candidates for deletion or a manual-test rewrite;
out of this plan's scope. qx_manual_test.livemd's 13
`draw_bloch(format: :svg) |> Kino.HTML.new()` sites get a mechanical
update in Phase 6 if the file survives.

## Naming decision detail

`Qx.draw_X → Qx.Draw.X` is the mechanical rule. Renames this forces:
`Draw.plot_counts → Draw.counts`, `Draw.bloch_sphere → Draw.bloch`.
`Draw.plot` keeps its name as `Qx.draw/2`'s target (documented
exception: the generic "chart this result" verb has no X).
