defmodule ExCellerate.Test.LimitRegistry do
  @moduledoc false
  use ExCellerate.Registry, cache_limit: 2
end
