defmodule ExCellerate.Functions.General.IfNull do
  @moduledoc false
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "ifnull"
  @impl true
  def arity, do: 2

  @impl true
  def call([val, default]) do
    if is_nil(val), do: default, else: val
  end
end
