defmodule ExCellerate.Test.DoubleFuncRegistry do
  defmodule Double do
    @behaviour ExCellerate.Function

    def name, do: "double"
    def arity, do: 1
    def call([n]), do: n * 2
  end

  use ExCellerate.Registry, plugins: [Double]
end
