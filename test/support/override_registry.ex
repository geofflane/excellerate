defmodule ExCellerate.Test.OverrideRegistry do
  defmodule MyAbs do
    @behaviour ExCellerate.Function

    def name, do: "abs"
    def arity, do: 1
    def call([_]), do: 42
  end

  use ExCellerate.Registry, plugins: [MyAbs]
end
