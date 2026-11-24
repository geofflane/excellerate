defmodule ExCellerate.Test.CustomIfRegistry do
  @moduledoc false
  # Overrides the built-in `if` with an ordinary (eager) function so tests can
  # check that lazy compilation applies only to the built-in, not to a
  # registry's own function of the same name.

  defmodule MyIf do
    @moduledoc false
    @behaviour ExCellerate.Function

    def name, do: "if"
    def arity, do: 3
    def call(args), do: [:custom_if | args]
  end

  use ExCellerate.Registry, plugins: [MyIf]
end
