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

  ## Arity

  The `arity/0` callback controls compile-time argument count validation:

  - **Fixed**: `def arity, do: 2` — requires exactly 2 arguments.
  - **Range**: `def arity, do: 1..2` — accepts 1 or 2 arguments (optional args).
  - **Variadic**: `def arity, do: :any` — accepts any number of arguments.

  ## Argument Validation

  Use `ExCellerate.Functions.Guards` for consistent runtime type checking
  in your `call/1` implementations. The guards produce descriptive
  `ExCellerate.Error` messages and reduce boilerplate:

      defmodule MyApp.Functions.Double do
        @behaviour ExCellerate.Function
        import ExCellerate.Functions.Guards

        def name, do: "double"
        def arity, do: 1

        def call([n]) when is_number(n), do: n * 2
        def call([other]), do: ensure_number!(other, name())
      end

  See `ExCellerate.Functions.Guards` for the full list of available helpers.
  """

  @doc "Returns the name of the function as it will be called in expressions."
  @callback name() :: String.t()

  @doc "Returns the expected number of arguments, a range for optional args, or :any."
  @callback arity() :: integer() | Range.t() | :any

  @doc "Executes the function logic with the provided list of arguments."
  @callback call(list(any())) :: any()
end
