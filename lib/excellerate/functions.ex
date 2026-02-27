defmodule ExCellerate.Functions do
  @moduledoc """
  Registry for ExCellerate functions.
  """

  @default_functions [
    ExCellerate.Functions.Math.Abs,
    ExCellerate.Functions.Math.Round,
    ExCellerate.Functions.Math.Floor,
    ExCellerate.Functions.Math.Ceil,
    ExCellerate.Functions.Math.Max,
    ExCellerate.Functions.Math.Min
  ]

  def list_defaults, do: @default_functions

  def get_default_function(name) do
    Enum.find(@default_functions, fn module -> module.name() == name end)
  end
end
