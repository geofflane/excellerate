defmodule ExCellerate.Functions.General.Len do
  @moduledoc false
  # Internal: Implements the 'len' function — returns the length of a string or list.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "len"
  @impl true
  def arity, do: 1

  @impl true
  def call([list]) when is_list(list), do: length(list)
  def call([str]) when is_binary(str), do: String.length(str)

  def call([other]) do
    raise ExCellerate.Error,
      message: "#{name()} expects a string or list, got: #{inspect(other)}",
      type: :runtime
  end
end
