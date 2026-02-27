defmodule ExCellerate.Functions do
  @moduledoc false
  # Internal: Manages the list of default built-in functions.

  @default_functions [
    ExCellerate.Functions.Math.Abs,
    ExCellerate.Functions.Math.Round,
    ExCellerate.Functions.Math.Floor,
    ExCellerate.Functions.Math.Ceil,
    ExCellerate.Functions.Math.Max,
    ExCellerate.Functions.Math.Min,
    ExCellerate.Functions.General.IfNull,
    ExCellerate.Functions.General.Concat,
    ExCellerate.Functions.General.Lookup,
    ExCellerate.Functions.General.If,
    ExCellerate.Functions.General.Normalize,
    ExCellerate.Functions.General.Substring,
    ExCellerate.Functions.General.Contains
  ]

  # Returns the list of modules for all default functions.
  @spec list_defaults() :: [module()]
  def list_defaults, do: @default_functions

  # Finds a default function by its string name.
  @spec get_default_function(String.t()) :: module() | nil
  def get_default_function(name) do
    Enum.find(@default_functions, fn module -> module.name() == name end)
  end
end
