defmodule ExCellerate.Functions.Math.Abs do
  @behaviour ExCellerate.Function
  def name, do: "abs"
  def arity, do: 1
  def call(args), do: abs(Enum.at(args, 0))
end

defmodule ExCellerate.Functions.Math.Round do
  @behaviour ExCellerate.Function
  def name, do: "round"
  def arity, do: 1
  def call(args), do: round(Enum.at(args, 0))
end

defmodule ExCellerate.Functions.Math.Floor do
  @behaviour ExCellerate.Function
  def name, do: "floor"
  def arity, do: 1
  def call(args), do: floor(Enum.at(args, 0))
end

defmodule ExCellerate.Functions.Math.Ceil do
  @behaviour ExCellerate.Function
  def name, do: "ceil"
  def arity, do: 1
  def call(args), do: ceil(Enum.at(args, 0))
end

defmodule ExCellerate.Functions.Math.Max do
  @behaviour ExCellerate.Function
  def name, do: "max"
  def arity, do: 2
  def call(args), do: max(Enum.at(args, 0), Enum.at(args, 1))
end

defmodule ExCellerate.Functions.Math.Min do
  @behaviour ExCellerate.Function
  def name, do: "min"
  def arity, do: 2
  def call(args), do: min(Enum.at(args, 0), Enum.at(args, 1))
end
