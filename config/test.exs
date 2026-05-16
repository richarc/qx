import Config

# Use Binary backend for tests to ensure deterministic doctest output
# The EXLA backend adds backend metadata to Nx.inspect output which
# causes doctest assertions to fail
config :nx, :default_backend, Nx.BinaryBackend

# Activate the compile-time norm-drift guard in Qx.Simulation so the
# suite fails fast if any circuit drifts beyond @norm_tolerance (1e-6).
config :qx, assert_norm: true
