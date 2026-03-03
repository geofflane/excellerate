defmodule ExCellerate.Functions.General.Normalize do
  @moduledoc """
  Converts a string to a normalized form by lowercasing it and replacing
  spaces with underscores.

  Non-string values are returned unchanged.

  ## Examples

      normalize('Hello World') → 'hello_world'
      normalize('First Name')  → 'first_name'
      normalize(42)            → 42
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "normalize"
  @impl true
  def arity, do: 1

  @impl true
  def call([val]) when is_binary(val) do
    val
    |> String.downcase()
    |> String.replace(" ", "_")
  end

  def call([val]), do: val
end
