defmodule ExCellerate.Functions.General.Find do
  @moduledoc false
  # Internal: Implements the 'find' function — returns the 0-based index
  # of the first occurrence of search in text, or -1 if not found.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "find"
  @impl true
  def arity, do: 2

  @impl true
  def call([search, text]) when is_binary(search) and is_binary(text) do
    case :binary.match(text, search) do
      {pos, _len} -> pos
      :nomatch -> -1
    end
  end

  def call([search, text]) do
    raise ExCellerate.Error,
      message: "#{name()} expects two strings, got: #{inspect(search)}, #{inspect(text)}",
      type: :runtime
  end
end
