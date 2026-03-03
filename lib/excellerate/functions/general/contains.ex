defmodule ExCellerate.Functions.General.Contains do
  @moduledoc """
  Returns `true` if a string contains the given substring, `false`
  otherwise.

  Returns `false` if either argument is not a string.

  ## Examples

      contains('Hello World', 'World') → true
      contains('Hello World', 'Foo')   → false
      contains(123, 'foo')             → false
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "contains"
  @impl true
  def arity, do: 2

  @impl true
  def call([str, substr]) when is_binary(str) and is_binary(substr) do
    String.contains?(str, substr)
  end

  def call(_), do: false
end
