defmodule Qx.Error do
  @moduledoc """
  Base exception for Qx library errors.
  """
  defexception [:message]
end

defmodule Qx.OptionError do
  @moduledoc """
  Raised when an option passed to a public Qx function is invalid.

  Carries the offending `:option` name and `:value` so callers can
  pattern-match on the cause rather than parsing the message.
  """
  defexception [:option, :value, :message]

  @impl true
  def exception({option, value, hint}) do
    %__MODULE__{
      option: option,
      value: value,
      message: "Invalid value for option #{inspect(option)}: #{inspect(value)}. #{hint}"
    }
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end

defmodule Qx.QubitIndexError do
  @moduledoc """
  Raised when a qubit index is out of range.
  """
  defexception [:qubit, :max, :message]

  @impl true
  def exception({qubit, max}) do
    %__MODULE__{
      qubit: qubit,
      max: max,
      message: "Qubit index #{qubit} out of range (0..#{max - 1})"
    }
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end

defmodule Qx.StateNormalizationError do
  @moduledoc """
  Raised when a quantum state is not properly normalized.

  A valid quantum state must satisfy ∑|ψᵢ|² = 1 (within tolerance).
  """
  defexception [:total_probability, :tolerance, :message]

  @impl true
  def exception({total, tolerance}) do
    %__MODULE__{
      total_probability: total,
      tolerance: tolerance,
      message: "State not normalized: total probability = #{total} (expected 1.0 ± #{tolerance})"
    }
  end

  def exception(total) when is_number(total) do
    exception({total, 1.0e-6})
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end

defmodule Qx.MeasurementError do
  @moduledoc """
  Raised when there are issues with quantum measurements.
  """
  defexception [:qubit, :message]

  @impl true
  def exception({:already_measured, qubit}) do
    %__MODULE__{
      qubit: qubit,
      message: "Qubit #{qubit} has already been measured"
    }
  end

  def exception({:pure_state_with_measurements}) do
    %__MODULE__{
      message: "Cannot get pure state from circuit with measurements"
    }
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end

defmodule Qx.ConditionalError do
  @moduledoc """
  Raised when there are issues with conditional operations.
  """
  defexception [:message]

  @impl true
  def exception(:nested_conditionals) do
    %__MODULE__{
      message: "Nested conditional operations are not supported"
    }
  end

  def exception({:bit_not_measured, bit}) do
    %__MODULE__{
      message: "Classical bit #{bit} must be measured before use in conditional"
    }
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end

defmodule Qx.ClassicalBitError do
  @moduledoc """
  Raised when a classical bit index is out of range.
  """
  defexception [:bit, :max, :message]

  @impl true
  def exception({bit, max}) do
    %__MODULE__{
      bit: bit,
      max: max,
      message: "Classical bit index #{bit} out of range (0..#{max - 1})"
    }
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end

defmodule Qx.GateError do
  @moduledoc """
  Raised when there are issues with gate operations.
  """
  defexception [:gate, :message]

  @impl true
  def exception({:unsupported_gate, gate}) do
    %__MODULE__{
      gate: gate,
      message: "Unsupported gate: #{inspect(gate)}"
    }
  end

  def exception({:invalid_parameter, gate, param}) do
    %__MODULE__{
      gate: gate,
      message: "Invalid parameter for gate #{gate}: #{inspect(param)}"
    }
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end

defmodule Qx.Hardware.NoMeasurementsError do
  @moduledoc """
  Raised when a circuit submitted to `Qx.Hardware` has no measurement
  instructions.

  Hardware backends return shot-based counts, so at least one measured
  qubit is required for the result to be meaningful.
  """
  defexception [:circuit_id, :message]

  @impl true
  def exception(%{__struct__: Qx.QuantumCircuit} = circuit) do
    id = Map.get(circuit, :id) || Map.get(circuit, :name)

    %__MODULE__{
      circuit_id: id,
      message:
        "Circuit has no measurement instructions. " <>
          "Hardware execution requires at least one `measure/2` call before submission."
    }
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end

defmodule Qx.Hardware.ExecutionError do
  @moduledoc """
  Raised by `Qx.Hardware.run!/3` (and friends) when the underlying
  pipeline returns `{:error, {stage, reason}}` and the caller asked for
  a bang variant.

  The `:stage` is one of the pipeline stage atoms documented on
  `Qx.Hardware` (`:config`, `:portal`, `:ibm_auth`, `:ibm_submit`,
  `:ibm_poll`, `:ibm_poll_timeout`, `:ibm_job_failed`, `:ibm_results`).
  """
  defexception [:stage, :reason, :message]

  @impl true
  def exception({stage, reason}) when is_atom(stage) do
    %__MODULE__{
      stage: stage,
      reason: reason,
      message: "Qx.Hardware pipeline failed at #{stage}: #{inspect(reason)}"
    }
  end

  def exception(reason) do
    %__MODULE__{
      message: "Qx.Hardware pipeline failed: #{inspect(reason)}"
    }
  end
end

defmodule Qx.Hardware.ConfigError do
  @moduledoc """
  Raised when a `Qx.Hardware.Config` value is invalid.

  The `:field` identifies which configuration key failed, and `:reason`
  carries a human-readable explanation.
  """
  defexception [:field, :reason, :message]

  @impl true
  def exception(opts) when is_list(opts) do
    field = Keyword.get(opts, :field)
    reason = Keyword.get(opts, :reason)
    message = Keyword.get(opts, :message) || format_message(field, reason)

    %__MODULE__{field: field, reason: reason, message: message}
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end

  defp format_message(nil, reason) when is_binary(reason), do: reason
  defp format_message(field, reason), do: "Invalid `#{field}`: #{reason}"
end

defmodule Qx.QubitCountError do
  @moduledoc """
  Raised when the number of qubits is invalid.
  """
  defexception [:count, :min, :max, :message]

  @impl true
  def exception({count, min, max}) do
    %__MODULE__{
      count: count,
      min: min,
      max: max,
      message: "Invalid qubit count: #{count} (must be between #{min} and #{max})"
    }
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end

defmodule Qx.QasmParseError do
  @moduledoc """
  Raised when an OpenQASM source string cannot be parsed.

  Includes the line and column where parsing failed, plus an excerpt of the
  surrounding source for debugging.
  """
  defexception [:line, :column, :snippet, :reason, :message]

  @impl true
  def exception(opts) when is_list(opts) do
    line = Keyword.get(opts, :line)
    column = Keyword.get(opts, :column)
    snippet = Keyword.get(opts, :snippet)
    reason = Keyword.get(opts, :reason, "syntax error")

    %__MODULE__{
      line: line,
      column: column,
      snippet: snippet,
      reason: reason,
      message: format_message(line, column, reason, snippet)
    }
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message, reason: message}
  end

  defp format_message(line, column, reason, snippet) do
    location =
      case {line, column} do
        {nil, _} -> ""
        {l, nil} -> " at line #{l}"
        {l, c} -> " at line #{l}, column #{c}"
      end

    suffix = if snippet, do: "\n  #{snippet}", else: ""
    "QASM parse error#{location}: #{reason}#{suffix}"
  end
end

defmodule Qx.QasmUnsupportedError do
  @moduledoc """
  Raised when an OpenQASM program uses a feature or gate that Qx does not
  currently support.

  The `feature` field identifies the construct (e.g., `"else branch"`,
  `"gate cy"`, `"reset"`), and `line`/`column` (when known) point at the
  offending source location.
  """
  defexception [:feature, :line, :column, :hint, :message]

  @impl true
  def exception(opts) when is_list(opts) do
    feature = Keyword.fetch!(opts, :feature)
    line = Keyword.get(opts, :line)
    column = Keyword.get(opts, :column)
    hint = Keyword.get(opts, :hint)

    %__MODULE__{
      feature: feature,
      line: line,
      column: column,
      hint: hint,
      message: format_message(feature, line, column, hint)
    }
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message, feature: message}
  end

  defp format_message(feature, line, column, hint) do
    location = format_location(line, column)
    suffix = if hint, do: ". #{hint}", else: ""
    "QASM feature not supported#{location}: #{feature}#{suffix}"
  end

  defp format_location(nil, _), do: ""
  defp format_location(line, nil), do: " at line #{line}"
  defp format_location(line, column), do: " at line #{line}, column #{column}"
end
