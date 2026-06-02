defmodule ExCellerate.Test.NoNativeRegistry do
  @moduledoc false
  use ExCellerate.Registry, compilation: ExCellerate.Compilation.Interpreted
end
