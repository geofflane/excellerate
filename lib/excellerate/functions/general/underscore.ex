defmodule ExCellerate.Functions.General.Underscore do
  @moduledoc """
  Converts a string to underscore case by downcasing, replacing spaces and
  slashes with underscores, and stripping other non-alphanumeric characters.

  ## Examples

      underscore('Hello World')   → 'hello_world'
      underscore('Hello/World')   → 'hello_world'
      underscore('Foo! @Bar#')    → 'foo_bar'
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "underscore"

  @impl true
  def arity, do: 1

  @impl true
  def call([val]) do
    ensure_string!(val, name())

    val
    |> String.downcase()
    |> String.replace(~r/\s/, "_")
    |> String.replace("/", "_")
    |> String.replace(~r/[^a-z0-9_]/, "")
  end
end
