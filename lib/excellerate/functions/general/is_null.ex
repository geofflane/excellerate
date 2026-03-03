defmodule ExCellerate.Functions.General.IsNull do
  @moduledoc """
  Returns `true` if a value is null, `false` otherwise.

  Unlike `isblank`, this only checks for null — empty strings and
  whitespace return `false`.

  ## Examples

      isnull(null)    → true
      isnull(0)       → false
      isnull('')      → false
      isnull('hello') → false
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "isnull"
  @impl true
  def arity, do: 1

  @impl true
  def call([nil]), do: true
  def call([_]), do: false
end
