import Config

# Use Binary backend for tests to ensure deterministic doctest output
# The EXLA backend adds backend metadata to Nx.inspect output which
# causes doctest assertions to fail
config :nx, :default_backend, Nx.BinaryBackend
