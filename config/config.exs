import Config

# Configure Nx to use EXLA backend for GPU/CPU acceleration
# EXLA provides JIT compilation via Google's XLA compiler
config :nx, :default_backend, EXLA.Backend

# Optional: Configure EXLA-specific options
# Uncomment the following to use GPU if available:
# config :nx, :default_backend, {EXLA.Backend, client: :cuda}

# For CPU-only with specific optimizations:
# config :nx, :default_backend, {EXLA.Backend, client: :host}

# EXLA compilation options
config :exla,
  # Preferred client (auto-detects GPU, falls back to CPU)
  preferred_clients: [:cuda, :rocm, :tpu, :host],
  # Memory fraction for GPU (if available)
  # Set to 0.9 to use 90% of GPU memory
  default_client: :host

# Note: To enable GPU support, you need:
# 1. CUDA toolkit installed (for NVIDIA GPUs)
# 2. ROCm installed (for AMD GPUs)
# 3. Appropriate XLA build with GPU support
#
# If GPU is not available, EXLA will automatically fall back to
# optimized CPU execution, which is still 10-50x faster than
# the default Nx.BinaryBackend.

# Import environment-specific config
if config_env() == :test do
  import_config "test.exs"
end
