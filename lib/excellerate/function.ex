defmodule ExCellerate.Function do
  @moduledoc """
  Defines a behaviour for implementing custom ExCellerate functions.

  Any module implementing this behaviour can be registered in an `ExCellerate.Registry`
  and called from within an expression.

  ## Example

      defmodule MyApp.Functions.Greet do
        @behaviour ExCellerate.Function

        def name, do: "greet"
        def arity, do: 1

        def call([name]) do
          "Hello, \#{name}!"
        end
      end
  """

  @doc "Returns the name of the function as it will be called in expressions."
  @callback name() :: String.t()

  @doc "Returns the expected number of arguments, or :any."
  @callback arity() :: integer() | :any

  @doc "Executes the function logic with the provided list of arguments."
  @callback call(list(any())) :: any()
end
