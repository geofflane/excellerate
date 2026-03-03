defmodule ExCellerate.Functions.General.If do
  @moduledoc """
  Returns one value if a condition is true and another if it is false.

  When called with two arguments, returns `null` when the condition is
  false. With three arguments, returns the third argument as the else
  value.

  ## Examples

      if(true, 'yes', 'no')       → 'yes'
      if(false, 'yes', 'no')      → 'no'
      if(score > 90, 'A', 'B')    → 'A' (when score is 95)
      if(active, 'on')            → 'on' (when active is true)
      if(false, 'on')             → null
  """
  @behaviour ExCellerate.Function

  @impl true
  def name, do: "if"
  @impl true
  def arity, do: 2..3

  @impl true
  def call([condition, then_val]) do
    if condition, do: then_val, else: nil
  end

  def call([condition, then_val, else_val]) do
    if condition, do: then_val, else: else_val
  end
end
