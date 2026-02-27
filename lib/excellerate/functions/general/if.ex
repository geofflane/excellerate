defmodule ExCellerate.Functions.General.If do
  @moduledoc false
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "if"
  @impl true
  def arity, do: 3

  @impl true
  def call([condition, then_val, else_val]) do
    if condition, do: then_val, else: else_val
  end
end
