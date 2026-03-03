defmodule ExCellerate.Functions.General.IfNull do
  @moduledoc """
  Returns the value if it is not null, otherwise returns the default.

  ## Examples

      ifnull(name, 'Anonymous') → 'Alice' (when name is 'Alice')
      ifnull(name, 'Anonymous') → 'Anonymous' (when name is null)
      ifnull(null, 0)           → 0
  """
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
