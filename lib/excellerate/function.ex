defmodule ExCellerate.Function do
  @moduledoc """
  Defines a behaviour for implementing ExCellerate functions.
  """

  @callback name() :: String.t()
  @callback arity() :: integer() | :any
  @callback call(list(any())) :: any()
end
