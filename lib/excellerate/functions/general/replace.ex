defmodule ExCellerate.Functions.General.Replace do
  @moduledoc false
  # Internal: Implements the 'replace' function — replaces all occurrences
  # of a substring. Equivalent to Excel's SUBSTITUTE.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "replace"
  @impl true
  def arity, do: 3

  @impl true
  def call([str, pattern, replacement])
      when is_binary(str) and is_binary(pattern) and is_binary(replacement) do
    String.replace(str, pattern, replacement)
  end

  def call([str, pattern, replacement]) do
    raise ExCellerate.Error,
      message:
        "#{name()} expects three strings, got: #{inspect(str)}, #{inspect(pattern)}, #{inspect(replacement)}",
      type: :runtime
  end
end
