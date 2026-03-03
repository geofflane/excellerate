defmodule ExCellerate.Functions.General.IsBlank do
  @moduledoc """
  Returns `true` if a value is null, an empty string, or a string
  containing only whitespace.

  Returns `false` for all other values including `0` and `false`.

  ## Examples

      isblank(null)   → true
      isblank('')     → true
      isblank('  ')   → true
      isblank('hello') → false
      isblank(0)      → false
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "isblank"
  @impl true
  def arity, do: 1

  @impl true
  def call([nil]), do: true

  def call([str]) when is_binary(str) do
    String.trim(str) == ""
  end

  def call([_]), do: false
end
