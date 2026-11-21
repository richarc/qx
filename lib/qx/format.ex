defmodule Qx.Format do
  @moduledoc false

  # Internal: shared formatting utilities for quantum states and complex
  # numbers. Used by `Qx.Draw`, `Qx.Draw.Tables`, `Qx.Draw.VegaLite`, and
  # `Qx.Register.show_state`. Not part of the public API.

  alias Complex, as: C

  # "Is this amplitude zero for display?" is answered here and nowhere
  # else. It is a question about rounding residue, so the answer is
  # absolute and set from the float width.
  #
  # Qx states are complex float32. Circuits built as U then U⁻¹, whose
  # exact result is |0…0⟩, were measured at 2 to 14 qubits and up to 1,740
  # gates: the largest probability left on another basis state was 2.3e-13
  # (amplitude 4.8e-7). The smallest probability of a uniform state at the
  # 20-qubit limit is 9.5e-7. The floor sits between the two, 400 times
  # above the first and 10,000 times below the second. Residue was not
  # measured from 15 to 20 qubits; it fell slightly with size up to 14.
  #
  # The floor is on a squared quantity: an amplitude error e on a basis
  # state that should be empty leaves probability e², so the amplitude
  # floor below is its square root.
  #
  # 1.0e-6 on probability is the wrong side of that gap: it is above
  # 9.5e-7, and hid every term of a 20-qubit uniform state.
  @noise_floor_probability 1.0e-10
  @noise_floor_amplitude 1.0e-5

  # When every term of a state would print as zero, this many of the
  # largest are shown.
  @fallback_terms 4

  @doc """
  True when a probability is rounding residue: at or under 1.0e-10. A
  basis state this unlikely is not shown by any display function.
  """
  def negligible?(probability) when is_number(probability),
    do: probability <= @noise_floor_probability

  # NaN and the infinities come out of a tensor as atoms. They are not
  # residue.
  def negligible?(_not_finite), do: false

  @doc """
  The terms of a state worth printing in a one-line summary, in index
  order, and whether any were cut by `:max`.

  A term is left out when its probability is negligible (see
  `negligible?/1`), or when its amplitude would print as all zeros at the
  precision asked for. If that leaves nothing, the largest terms that are
  not negligible are kept; a zero vector keeps its first term.

  ## Options
  - `:precision` - Decimal places the amplitudes will be printed with
    (default: 3)
  - `:max` - Keep at most this many terms (default: no limit)

  ## Examples

      iex> terms = [
      ...>   {"|0⟩", Complex.new(1.0, 0.0), 1.0},
      ...>   {"|1⟩", Complex.new(1.0e-7, 0.0), 1.0e-14}
      ...> ]
      iex> {[{basis, _amplitude, _probability}], false} = Qx.Format.significant_terms(terms)
      iex> basis
      "|0⟩"
  """
  def significant_terms(terms, opts \\ []) do
    precision = Keyword.get(opts, :precision, 3)
    max = Keyword.get(opts, :max, :infinity)

    present =
      Enum.reject(terms, fn {_basis, _amplitude, probability} -> negligible?(probability) end)

    printable =
      Enum.filter(present, fn {_basis, amplitude, _prob} -> prints?(amplitude, precision) end)

    cond do
      printable != [] -> limit(printable, max)
      present != [] -> largest(present, max)
      true -> {Enum.take(terms, 1), false}
    end
  end

  # An amplitude prints as something other than zeros when either part
  # rounds to at least one unit of the last decimal.
  defp prints?(amplitude, precision) do
    {re, im} = parts(amplitude)
    half_unit = 0.5 * :math.pow(10, -precision)
    part_prints?(re, half_unit) or part_prints?(im, half_unit)
  end

  defp part_prints?(part, half_unit) when is_number(part), do: abs(part) >= half_unit
  # Not finite: not zero.
  defp part_prints?(_part, _half_unit), do: true

  defp parts(%Complex{re: re, im: im}), do: {re, im}
  defp parts(number) when is_number(number), do: {number, 0.0}

  defp limit(terms, :infinity), do: {terms, false}

  defp limit(terms, max) do
    {kept, rest} = Enum.split(terms, max)
    {kept, rest != []}
  end

  # The largest terms, back in index order. Any that are not shown count
  # as cut.
  defp largest(present, max) do
    count = if max == :infinity, do: @fallback_terms, else: min(max, @fallback_terms)

    kept =
      present
      |> Enum.with_index()
      |> Enum.sort_by(fn {{_basis, _amplitude, probability}, index} -> {-probability, index} end)
      |> Enum.take(count)
      |> Enum.sort_by(fn {_term, index} -> index end)
      |> Enum.map(fn {term, _index} -> term end)

    {kept, length(present) > length(kept)}
  end

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

  Prints the terms `significant_terms/2` keeps, in standard quantum
  notation: rounding residue and terms that would print as zeros are left
  out.

  ## Parameters
  - `amplitudes_and_probs` - List of tuples: `{basis_label, amplitude, probability}`

  ## Options
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
    precision = Keyword.get(opts, :precision, 3)
    {terms, _cut?} = significant_terms(amplitudes_and_probs, precision: precision)

    terms
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {{basis, amplitude, _prob}, index} ->
      format_term(basis, amplitude, precision, index == 0)
    end)
  end

  defp format_term(basis, amplitude, precision, is_first) do
    {re, im} = parts(amplitude)

    if abs(im) < @noise_floor_amplitude do
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
