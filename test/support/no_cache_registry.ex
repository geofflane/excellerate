defmodule ExCellerate.Test.NoCacheRegistry do
  @moduledoc false
  use ExCellerate.Registry, cache_enabled: false
end
