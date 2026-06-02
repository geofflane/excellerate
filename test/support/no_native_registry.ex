defmodule ExCellerate.Test.NoNativeRegistry do
  @moduledoc false
  use ExCellerate.Registry, native_compilation: false
end
