defmodule ExCellerate.Functions.General.Slug do
  @moduledoc """
  Converts a string to a slug by downcasing, replacing spaces and slashes
  with hyphens, and stripping other non-alphanumeric characters.

  ## Examples

      slug('Hello World')   → 'hello-world'
      slug('Hello/World')   → 'hello-world'
      slug('Foo! @Bar#')    → 'foo-bar'
  """
  @behaviour ExCellerate.Function

  import ExCellerate.Functions.Guards

  @impl true
  def name, do: "slug"

  @impl true
  def arity, do: 1

  @impl true
  def call([val]) do
    ensure_string!(val, name())

    val
    |> String.downcase()
    |> String.replace(~r/\s/, "-")
    |> String.replace("/", "-")
    |> String.replace(~r/[^a-z0-9-]/, "")
  end
end
