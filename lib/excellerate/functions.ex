defmodule ExCellerate.Functions do
  @moduledoc false
  # Internal: Manages the list of default built-in functions.

  @default_functions [
    # Math
    ExCellerate.Functions.Math.Abs,
    ExCellerate.Functions.Math.Round,
    ExCellerate.Functions.Math.Floor,
    ExCellerate.Functions.Math.Ceil,
    ExCellerate.Functions.Math.Max,
    ExCellerate.Functions.Math.Min,
    ExCellerate.Functions.Math.Sqrt,
    ExCellerate.Functions.Math.Log,
    ExCellerate.Functions.Math.Ln,
    ExCellerate.Functions.Math.Log10,
    ExCellerate.Functions.Math.Exp,
    ExCellerate.Functions.Math.Sign,
    ExCellerate.Functions.Math.Trunc,
    ExCellerate.Functions.Math.Sum,
    ExCellerate.Functions.Math.Avg,
    # String
    ExCellerate.Functions.General.Concat,
    ExCellerate.Functions.General.Contains,
    ExCellerate.Functions.General.Find,
    ExCellerate.Functions.General.Left,
    ExCellerate.Functions.General.Len,
    ExCellerate.Functions.General.Lower,
    ExCellerate.Functions.General.Normalize,
    ExCellerate.Functions.General.Replace,
    ExCellerate.Functions.General.Right,
    ExCellerate.Functions.General.Substring,
    ExCellerate.Functions.General.TextJoin,
    ExCellerate.Functions.General.Trim,
    ExCellerate.Functions.General.Upper,
    # Utility
    ExCellerate.Functions.General.And,
    ExCellerate.Functions.General.Coalesce,
    ExCellerate.Functions.General.If,
    ExCellerate.Functions.General.IfNull,
    ExCellerate.Functions.General.Lookup,
    ExCellerate.Functions.General.Or,
    ExCellerate.Functions.General.Switch
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
