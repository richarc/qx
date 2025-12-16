defmodule Qx.Format do
  @moduledoc """
  Shared formatting utilities for quantum states and complex numbers.

  This module provides consistent formatting across the Qx library for:
  - Complex numbers in "a+bi" notation
  - Basis state labels in ket notation (|00⟩, |01⟩, etc.)
  - Dirac notation for quantum state representation

  ## Examples

      # Format complex numbers
      iex> Qx.Format.complex(Complex.new(0.707, 0.5))
      "0.707+0.500i"

      # Format basis states
      iex> Qx.Format.basis_state(3, 2)
      "|11⟩"

      # Build Dirac notation
      iex> amplitudes = [
      ...>   {"|00⟩", Complex.new(0.707, 0.0), 0.5},
      ...>   {"|01⟩", Complex.new(0.0, 0.0), 0.0},
      ...>   {"|10⟩", Complex.new(0.707, 0.0), 0.5}
      ...> ]
      iex> Qx.Format.dirac_notation(amplitudes)
      "0.707|00⟩ + 0.707|10⟩"
  """

  alias Complex, as: C

  @doc """
  Formats a complex number as "a+bi" notation.

  ## Options
  - `:precision` - Number of decimal places (default: 3)
  - `:format` - `:erlang` (default, faster) or `:float`

  ## Examples

      iex> Qx.Format.complex(Complex.new(0.707, 0.5))
      "0.707+0.500i"

      iex> Qx.Format.complex(Complex.new(1.0, -0.5), precision: 2)
      "1.00-0.50i"

      iex> Qx.Format.complex(Complex.new(0.0, 0.0))
      "0.000+0.000i"
  """
  def complex(complex_num, opts \\ []) do
    precision = Keyword.get(opts, :precision, 3)
    format = Keyword.get(opts, :format, :erlang)

    real = C.real(complex_num)
    imag = C.imag(complex_num)

    {real_str, imag_str} =
      case format do
        :erlang ->
          {:erlang.float_to_binary(real, decimals: precision),
           :erlang.float_to_binary(abs(imag), decimals: precision)}

        :float ->
          {Float.round(real, precision) |> to_string(),
           Float.round(abs(imag), precision) |> to_string()}
      end

    sign = if imag >= 0, do: "+", else: "-"
    "#{real_str}#{sign}#{imag_str}i"
  end

  @doc """
  Formats a basis state index as ket notation: |00⟩, |01⟩, etc.

  ## Parameters
  - `index` - The basis state index (0-based)
  - `num_qubits` - Number of qubits in the system

  ## Examples

      iex> Qx.Format.basis_state(0, 2)
      "|00⟩"

      iex> Qx.Format.basis_state(3, 2)
      "|11⟩"

      iex> Qx.Format.basis_state(5, 3)
      "|101⟩"
  """
  def basis_state(index, num_qubits) when is_integer(index) and is_integer(num_qubits) do
    binary_string =
      Integer.to_string(index, 2)
      |> String.pad_leading(num_qubits, "0")

    "|#{binary_string}⟩"
  end

  @doc """
  Builds Dirac notation string from amplitudes and probabilities.

  Filters out basis states with negligible probability and formats the
  remaining terms in standard quantum notation.

  ## Parameters
  - `amplitudes_and_probs` - List of tuples: `{basis_label, amplitude, probability}`

  ## Options
  - `:threshold` - Minimum probability to include (default: 1.0e-6)
  - `:precision` - Decimal precision for magnitudes (default: 3)

  ## Examples

      iex> amplitudes_and_probs = [
      ...>   {"|00⟩", Complex.new(0.707, 0.0), 0.5},
      ...>   {"|01⟩", Complex.new(0.0, 0.0), 0.0},
      ...>   {"|10⟩", Complex.new(0.707, 0.0), 0.5},
      ...>   {"|11⟩", Complex.new(0.0, 0.0), 0.0}
      ...> ]
      iex> Qx.Format.dirac_notation(amplitudes_and_probs)
      "0.707|00⟩ + 0.707|10⟩"

      iex> # Bell state |Φ+⟩ = (|00⟩ + |11⟩)/√2
      iex> bell_state = [
      ...>   {"|00⟩", Complex.new(0.707, 0.0), 0.5},
      ...>   {"|11⟩", Complex.new(0.707, 0.0), 0.5}
      ...> ]
      iex> Qx.Format.dirac_notation(bell_state)
      "0.707|00⟩ + 0.707|11⟩"

      iex> # Minus state |-⟩ = (|0⟩ - |1⟩)/√2
      iex> minus_state = [
      ...>   {"|0⟩", Complex.new(0.707, 0.0), 0.5},
      ...>   {"|1⟩", Complex.new(-0.707, 0.0), 0.5}
      ...> ]
      iex> Qx.Format.dirac_notation(minus_state)
      "0.707|0⟩ - 0.707|1⟩"
  """
  def dirac_notation(amplitudes_and_probs, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 1.0e-6)
    precision = Keyword.get(opts, :precision, 3)

    # Filter out near-zero amplitudes
    significant_terms =
      amplitudes_and_probs
      |> Enum.filter(fn {_basis, _amp, prob} -> prob > threshold end)

    if Enum.empty?(significant_terms) do
      # Shouldn't happen with normalized state, but handle it gracefully
      {basis, _, _} = List.first(amplitudes_and_probs)
      "0.000#{basis}"
    else
      significant_terms
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {{basis, amplitude, _prob}, index} ->
        format_term(basis, amplitude, precision, index == 0)
      end)
    end
  end

  defp format_term(basis, amplitude, precision, is_first) do
    # Handle Complex struct or number
    {re, im} =
      case amplitude do
        %Complex{re: r, im: i} -> {r, i}
        n when is_number(n) -> {n, 0.0}
      end

    if abs(im) < 1.0e-6 do
      # Real number
      val = re
      abs_val = abs(val)
      val_str = :erlang.float_to_binary(abs_val, decimals: precision)

      cond do
        val >= 0 and is_first -> "#{val_str}#{basis}"
        val >= 0 -> "+ #{val_str}#{basis}"
        val < 0 -> "- #{val_str}#{basis}"
      end
    else
      # Complex number
      c_str = complex(amplitude, precision: precision)

      if is_first do
        "(#{c_str})#{basis}"
      else
        "+ (#{c_str})#{basis}"
      end
    end
  end

  @doc """
  Formats state label for visualization.

  This is a convenience function that handles both:
  - num_qubits directly
  - state_size (dimension of Hilbert space) - converts to num_qubits

  ## Examples

      iex> Qx.Format.state_label(3, 2)  # 3 in 2-qubit system
      "|11⟩"

      iex> Qx.Format.state_label(5, 8)  # 5 in 8-dimensional space (3 qubits)
      "|101⟩"
  """
  def state_label(index, num_qubits_or_size) do
    num_qubits =
      if power_of_two?(num_qubits_or_size) and num_qubits_or_size > 2 do
        # It's a state size (dimension), convert to num_qubits
        trunc(:math.log2(num_qubits_or_size))
      else
        # It's already num_qubits
        num_qubits_or_size
      end

    basis_state(index, num_qubits)
  end

  # Private helpers

  # Check if a number is a power of 2
  defp power_of_two?(n) when n > 0 do
    Bitwise.band(n, n - 1) == 0
  end

  defp power_of_two?(_), do: false
end
