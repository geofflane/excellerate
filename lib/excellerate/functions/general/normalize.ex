defmodule ExCellerate.Functions.General.Normalize do
  @moduledoc false
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
