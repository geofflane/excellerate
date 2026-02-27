defmodule ExCellerate.Functions.Math.Abs do
  @moduledoc false
  # Internal: Implements the 'abs' function.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "abs"
  @impl true
  def arity, do: 1
  @impl true
  def call([n]), do: abs(n)
end

defmodule ExCellerate.Functions.Math.Round do
  @moduledoc false
  # Internal: Implements the 'round' function.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "round"
  @impl true
  def arity, do: 1
  @impl true
  def call([n]), do: round(n)
end

defmodule ExCellerate.Functions.Math.Floor do
  @moduledoc false
  # Internal: Implements the 'floor' function.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "floor"
  @impl true
  def arity, do: 1
  @impl true
  def call([n]), do: floor(n)
end

defmodule ExCellerate.Functions.Math.Ceil do
  @moduledoc false
  # Internal: Implements the 'ceil' function.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "ceil"
  @impl true
  def arity, do: 1
  @impl true
  def call([n]), do: ceil(n)
end

defmodule ExCellerate.Functions.Math.Max do
  @moduledoc false
  # Internal: Implements the 'max' function.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "max"
  @impl true
  def arity, do: 2
  @impl true
  def call([a, b]), do: max(a, b)
end

defmodule ExCellerate.Functions.Math.Min do
  @moduledoc false
  # Internal: Implements the 'min' function.
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "min"
  @impl true
  def arity, do: 2
  @impl true
  def call([a, b]), do: min(a, b)
end
