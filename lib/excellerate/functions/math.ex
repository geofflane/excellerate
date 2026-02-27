defmodule ExCellerate.Functions.Math.Abs do
  @moduledoc false
  # Internal: Implements the 'abs' function.
  @behaviour ExCellerate.Function
  def name, do: "abs"
  def arity, do: 1
  def call(args), do: abs(Enum.at(args, 0))
end

defmodule ExCellerate.Functions.Math.Round do
  @moduledoc false
  # Internal: Implements the 'round' function.
  @behaviour ExCellerate.Function
  def name, do: "round"
  def arity, do: 1
  def call(args), do: round(Enum.at(args, 0))
end

defmodule ExCellerate.Functions.Math.Floor do
  @moduledoc false
  # Internal: Implements the 'floor' function.
  @behaviour ExCellerate.Function
  def name, do: "floor"
  def arity, do: 1
  def call(args), do: floor(Enum.at(args, 0))
end

defmodule ExCellerate.Functions.Math.Ceil do
  @moduledoc false
  # Internal: Implements the 'ceil' function.
  @behaviour ExCellerate.Function
  def name, do: "ceil"
  def arity, do: 1
  def call(args), do: ceil(Enum.at(args, 0))
end

defmodule ExCellerate.Functions.Math.Max do
  @moduledoc false
  # Internal: Implements the 'max' function.
  @behaviour ExCellerate.Function
  def name, do: "max"
  def arity, do: 2
  def call(args), do: max(Enum.at(args, 0), Enum.at(args, 1))
end

defmodule ExCellerate.Functions.Math.Min do
  @moduledoc false
  # Internal: Implements the 'min' function.
  @behaviour ExCellerate.Function
  def name, do: "min"
  def arity, do: 2
  def call(args), do: min(Enum.at(args, 0), Enum.at(args, 1))
end
