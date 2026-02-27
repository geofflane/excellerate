defmodule ExCellerate.Test.OverrideRegistry do
  @moduledoc false

  defmodule MyAbs do
    @moduledoc false
    @behaviour ExCellerate.Function

    def name, do: "abs"
    def arity, do: 1
    def call([_]), do: 42
  end

  use ExCellerate.Registry, plugins: [MyAbs]
end
